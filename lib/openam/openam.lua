
-- Copyright (c) 2014 gsick --


-- dependencies

local http = require "resty.http"
local cjson_safe = require "cjson.safe"


-- default cookie params

local DEFAULT_COOKIE = {
  name = nil,
  openam_name = "iplanetDirectoryPro",
  domain = ngx.req.get_headers()["Host"],
  secure = false,
  http_only = true,
  path = "/",
}


-- default rules for redirects

local DEFAULT_REDIRECT = {
  follow_success_url = false,
  follow_failure_url = false,
}


-- session cookie value

local function getSessionCookie(cookie)
  local nginx_cookie_name = "cookie_" .. cookie.name
  local cookie = ngx.var[nginx_cookie_name]
  return cookie
end


-- add session cookie

local function setSessionCookie(cookie, token, expired)

  local final_cookie = cookie.name .. '=' .. token
  final_cookie = final_cookie .. '; path=' .. cookie.path
  final_cookie = final_cookie .. '; domain=' .. cookie.domain

  if cookie.secure then
    final_cookie = final_cookie .. '; secure'
  end

  if cookie.http_only then
    final_cookie = final_cookie .. '; HttpOnly'
  end

  if expired then
    final_cookie = final_cookie .. "; Expires=" .. ngx.cookie_time(0)
  end

  ngx.header.set_cookie = final_cookie
end


-- decode json response, exit if error

local function jsonDecode(cjson, text)
  local json, err = cjson.decode(text)
  if not json then
    if err and text then
      ngx.log(ngx.ERR, "error: " .. err .. " text: " .. text)
    end
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  return json
end


-- log for better parsing
-- [response status,token,usernam,url/uri,response body/cmd result]

local function log(level, cmd, status, token, username, uri, text)

  local s = '['
  s = s .. (cmd and cmd or '') .. '|'
  s = s .. (status and status or '') .. '|'
  s = s .. (token and token or '') .. '|'
  s = s .. (username and username or '') .. '|'
  s = s .. (uri and uri or '') .. '|'
  s = s .. (text and text or '') .. '|'
  s = s .. ']'

  ngx.log(level, s)
end



local _Openam = {
  _VERSION = '0.0.1',
}


local mt = { __index = _Openam }


function _Openam.new(uri, cookie_params, redirect_params)

  -- TODO clean code
  cookie = DEFAULT_COOKIE

  if cookie_params then

    if cookie_params.openam_name ~= nil then
      cookie.openam_name = cookie_params.openam_name
    end
    if cookie_params.name ~= nil then
      cookie.name = cookie_params.name
    end
    if cookie_params.domain ~= nil then
      cookie.domain = cookie_params.domain
    end
    if cookie_params.secure ~= nil then
      cookie.secure = cookie_params.secure
    end
    if cookie_params.http_only ~= nil then
      cookie.http_only = cookie_params.http_only
    end
    if cookie_params.path ~= nil then
      cookie.path = cookie_params.path
    end
  end

  if cookie.name == nil then
    -- same cookie/token name for both side if cookie.name == nil
    cookie.name = cookie.openam_name
  end

  redirect = DEFAULT_REDIRECT

  if redirect_params then
    if redirect_params.follow_success_url ~= nil then
      redirect.follow_success_url = redirect_params.follow_success_url
    end
    if redirect_params.follow_failure_url ~= nil then
      redirect.follow_failure_url = redirect_params.follow_failure_url
    end
  end

  local cjson = cjson_safe.new()
  local httpc, err = http.new()

  -- If no ngx_socket_tcp then return 403
  if not httpc then
    if err then
      ngx.log(ngx.ERR, err)
    end
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end

  return setmetatable({ httpc = httpc, uri = uri, cookie = cookie, redirect = redirect, cjson = cjson }, mt)
end


-- https://openam.example.com:8443/openam/json[/myRealm]/authenticate
-- 200 { "tokenId": "AQIC5w...NTcy*", "successUrl": "/openam/console" }
-- 401 { "errorMessage": "Invalid Password!!", "failureUrl": "http://www.example.com/401.html" } ??
-- 401 {"code":401,"reason":"Unauthorized","message":"Invalid Password!!"}

function _Openam.authenticate(self, username, password, realm)

  -- TODO should check username, password != nil ?

  local httpc = self.httpc
  local cjson = self.cjson
  local uri = self.uri .. "/json"
  
  if realm then
    uri = uri .. realm
  end

  uri = uri .. "/authenticate"

  ngx.log(ngx.DEBUG, uri)

  local res, err = httpc:request_uri(uri, {
    method = "POST",
    body = "",
    headers = {
      ["Content-Type"] = "application/json",
      ["X-OpenAM-Username"] = username,
      ["X-OpenAM-Password"] = password,
    }
  })

  if res then
    ngx.log(ngx.DEBUG, res.body)

    local json = jsonDecode(cjson, res.body)

    if res.status == ngx.HTTP_OK and json.tokenId then

      -- Set session cookie
      setSessionCookie(self.cookie, json.tokenId)

      log(ngx.NOTICE, "authenticate", res.status, json.tokenId, username, nil, nil)

      -- Redirect to success url
      if self.redirect.follow_success_url and json.successUrl then
        log(ngx.NOTICE, "authenticate", res.status, json.tokenId, username, json.successUrl, nil)
        ngx.redirect(json.successUrl)
      end

      return ngx.HTTP_OK, json
    end

    -- Eliminate the callback authentication mode when there is json.authId and status 200 (no tokenId)
    if res.status == ngx.HTTP_UNAUTHORIZED or (res.status == ngx.HTTP_OK and json.tokenId == nil) then
      log(ngx.WARN, "authenticate", ngx.HTTP_UNAUTHORIZED, nil, username, nil, res.body)

      -- Redirect to failure url
      if self.redirect.follow_failure_url and json.failureUrl then
        log(ngx.NOTICE, "authenticate", ngx.HTTP_UNAUTHORIZED, nil, username, json.failureUrl, nil)
        ngx.redirect(json.failureUrl)
      end

      return ngx.HTTP_UNAUTHORIZED, json
    end

    -- should never be 200 here
    log(ngx.ERR, "authenticate", res.status, nil, username, uri, res.body)
    return res.status, nil
  end

  if err then
    ngx.log(ngx.ERR, err)
  end

  -- default return 500
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end


-- https://openam.example.com:8443/openam/json/sessions/?_action=logout
-- 200 {"result":"Successfully logged out"}
-- 401 { "code": 401, "reason": "Unauthorized", "message": "Access Denied" }

function _Openam.logout(self, token)

  local httpc = self.httpc
  local cjson = self.cjson
  local uri = self.uri .. "/json/sessions/?_action=logout"

  -- security test, return error if no token found in cookie
  token = token and token or getSessionCookie(self.cookie)
  if not token then
    ngx.log(ngx.ERR, "no token found in the request")
    return ngx.HTTP_UNAUTHORIZED, nil
  end

  ngx.log(ngx.DEBUG, uri)

  local res, err = httpc:request_uri(uri, {
    method = "POST",
    body = "",
    headers = {
      ["Content-Type"] = "application/json",
      [self.cookie.openam_name] = token,
    }
  })

  if res then
    ngx.log(ngx.DEBUG, res.body)

    local json = jsonDecode(cjson, res.body)

    -- expire cookie even if there is a response with error
    setSessionCookie(self.cookie, token, true)

    -- openam send 401 when the token is expired, I forgive it, logout become ok
    if res.status == ngx.HTTP_OK or res.status == ngx.HTTP_UNAUTHORIZED then
      log(ngx.NOTICE, "logout", ngx.HTTP_OK, token, nil, nil, nil)
      return ngx.HTTP_OK, json
    end

    -- there is an error, I forgive openam again
    -- a cookie expired is sent and logout become ok even if the session is maybe still alive in openam
    log(ngx.ERR, "logout", res.status, token, nil, uri, res.body)
    return ngx.HTTP_OK, json
  end

  if err then
    ngx.log(ngx.ERR, err)
  end

  -- default return 500
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end


-- tranform weird response "boolean=true" or "boolean=false" to json with a custom key

local function booleanResponseDecode(cjson, text, key_name)
  local valid = false
  local m, err = ngx.re.match(text, "(true)|(false)")

  if m then
    valid = m[0]
  end

  if err then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  local json = jsonDecode(cjson, "{\"" .. key_name .. "\":" .. tostring(valid) .. "}")

  return json
end


-- https://openam.example.com:8443/openam/identity/isTokenValid
-- 200 boolean=true
-- 200 boolean=false

function _Openam.isTokenValid(self, logout, token)

  local httpc = self.httpc
  local cjson = self.cjson
  local uri = self.uri .. "/identity/isTokenValid"

  -- security test, return error if no token found in cookie
  token = token and token or getSessionCookie(self.cookie)
  if not token then
    ngx.log(ngx.ERR, "no token found in the request")
    return ngx.HTTP_UNAUTHORIZED, nil
  end

  ngx.log(ngx.DEBUG, uri)

  local res, err = httpc:request_uri(uri, {
    method = "POST",
    body = "tokenid=" .. token,
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
    }
  })

  if res then
    ngx.log(ngx.DEBUG, res.body)

    if res.status == ngx.HTTP_OK then

      local json = booleanResponseDecode(cjson, res.body, "valid")

      log(ngx.NOTICE, "isTokenValid", res.status, token, nil, nil, tostring(json.valid))

      if not json.valid then
        if logout then
          return self:logout(token)
        end
        return ngx.HTTP_UNAUTHORIZED, json
      else
        return ngx.HTTP_OK, json
      end
    end

    log(ngx.ERR, "isTokenValid", res.status, token, nil, uri, res.body)
    return res.status, nil
  end

  if err then
    ngx.log(ngx.ERR, err)
  end

  -- default return 500
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end


-- "https://openam.example.com:8443/openam/identity/authorize?
-- uri=http%3A%2F%2Fwww.example.com%3A8080%2Fexamples%2Findex.html
-- &subjectid=AQIC5wM2LY4SfcxuxIP0VnP2lVjs7ypEM6VDx6srk56CN1Q.*AAJTSQACMDE.*"
-- 200 boolean=true
-- 200 boolean=false

function _Openam.authorize(self, uri_value, token)

  local httpc = self.httpc
  local cjson = self.cjson
  local uri = self.uri .. "/identity/authorize?"

  -- security test, return error if no token found in cookie
  token = token and token or getSessionCookie(self.cookie)
  if not token then
    ngx.log(ngx.ERR, "no token found in the request")
    return ngx.HTTP_UNAUTHORIZED, nil
  end

  if not uri_value then
    uri_value = ngx.var.scheme .. "://" .. ngx.var.host .. ngx.var.uri
  end

  uri = uri .. "uri=" .. ngx.escape_uri(uri_value) .. "&subjectid=" .. ngx.escape_uri(token)

  ngx.log(ngx.DEBUG, uri)

  local res, err = httpc:request_uri(uri, {
    method = "GET",
    body = "",
    headers = {
      -- ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Content-Type"] = "text/plain",
    }
  })

  if res then
    ngx.log(ngx.DEBUG, res.body)

    if res.status == ngx.HTTP_OK then

      local json = booleanResponseDecode(cjson, res.body, "authorize")

      log(ngx.NOTICE, "authorize", res.status, token, nil, uri_value, tostring(json.authorize))

      if json.authorize then
        return res.status, json
      end

      return ngx.HTTP_UNAUTHORIZED, json
    end

    log(ngx.ERR, "authorize", res.status, token, nil, uri, res.body)
    return res.status, nil
  end

  if err then
    ngx.log(ngx.ERR, err)
  end

  -- default return 500
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end


-- https://openam.example.com:8443/openam/json[/realm]/users/demo
-- https://openam.example.com:8443/openam/json[/realm]/users/demo?_fields=name,uid
-- admin
-- 200 {"username":"amadmin","realm":"dc=openam,dc=forgerock,dc=org","mail":[],
-- "sunidentitymsisdnnumber":[],"sn":["amAdmin"],"givenname":["amAdmin"],"telephonenumber":[],
-- "universalid":["id=amadmin,ou=user,dc=openam,dc=forgerock,dc=org"],"employeenumber":[],
-- "postaladdress":[],"cn":["amAdmin"],"iplanet-am-user-success-url":[],"roles":[],
-- "iplanet-am-user-failure-url":[],"inetuserstatus":["Active"],
-- "dn":["uid=amAdmin,ou=people,dc=openam,dc=forgerock,dc=org"],"iplanet-am-user-alias-list":[]}
-- user
-- 200 {"username":".....","realm":"dc=openam,dc=forgerock,dc=org","uid":["...."],
-- "sn":["...."],"userPassword":["{SSHA}...."],
-- "cn":["...."],"givenName":["...."],"inetUserStatus":["Active"],
-- "dn":["uid=....,ou=people,dc=....,dc=...."],"objectClass":["devicePrintProfilesContainer",
-- "person","sunIdentityServerLibertyPPService","inetorgperson","sunFederationManagerDataStore",
-- "iPlanetPreferences","iplanet-am-auth-configuration-service","organizationalperson","sunFMSAML2NameIdentifier",
-- "inetuser","forgerock-am-dashboard-service","iplanet-am-managed-person","iplanet-am-user-service",
-- "sunAMAuthAccountLockout","top"],"universalid":["id=....,ou=user,dc=openam,dc=forgerock,dc=org"]}
-- 404 {"code":404,"reason":"Not Found","message":"Resource cannot be found."},

function _Openam.readIdentity(self, user, fields, realm, token)

  local httpc = self.httpc
  local cjson = self.cjson
  local uri = self.uri .. "/json"

  if realm then
    uri = uri .. realm
  end

  uri = uri .. "/users/" .. ngx.escape_uri(user)

  if fields then
    uri = uri .. "?_fields=" .. ngx.escape_uri(fields)
  end

  -- security test, return error if no token found in cookie
  token = token and token or getSessionCookie(self.cookie)
  if not token then
    ngx.log(ngx.ERR, "no token found in the request")
    return ngx.HTTP_UNAUTHORIZED, nil
  end

  ngx.log(ngx.DEBUG, uri)

  local res, err = httpc:request_uri(uri, {
    method = "GET",
    body = "",
    headers = {
      ["Content-Type"] = "application/json",
      [self.cookie.openam_name] = token,
    }
  })

  if res then
    ngx.log(ngx.DEBUG, res.body)

    if res.status == ngx.HTTP_OK then

      local json = jsonDecode(cjson, res.body)

      log(ngx.NOTICE, "readIdentity", res.status, token, user, nil, nil)

      return res.status, json
    end

    log(ngx.ERR, "readIdentity", res.status, token, user, uri, res.body)
    return res.status, nil
  end

  if err then
    ngx.log(ngx.ERR, err)
  end

  -- default return 500
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

return _Openam