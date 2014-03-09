lua-openam
==========

Lua OpenAM client driver for the nginx [HttpLuaModule](http://wiki.nginx.org/HttpLuaModule).<br />
Use [OpenAM RESTful API](http://openam.forgerock.org/openam-documentation/openam-doc-source/doc/dev-guide/index/chap-rest.html).<br />
It is different than an OpenAM agent.<br />

## Status

beta, the api may be change.

## Dependencies

* [Lua CJSON](http://www.kyne.com.au/~mark/software/lua-cjson.php)
* [lua-resty-http](https://github.com/pintsized/lua-resty-http)

## Synopsis

```lua
lua_package_cpath "/usr/lib64/lua/5.1/?.so;;";
lua_package_path "/usr/lib64/lua/5.1/resty/http/?.lua;/usr/lib64/lua/5.1/openam/?.lua;;";

server {

  location /login.html {
    access_by_lua '

      local openam = require "openam"
      local openam_uri = "http://openam.example.com:8080/openam"

      local obj = openam.new(openam_uri, {name = "session"}, {success_url = false})
      local status, json = obj:authenticate("my_login", "my_password")

      if not status == ngx.HTPP_OK then
        -- do something
        -- e.g. ngx.redirect(...), ngx.exit(...)
      end
      -- session cookie added in the http response
    ';
    # proxy_pass/to/somewhere/...
  }

  location /resource.html {
    access_by_lua '

      local openam = require "openam"
      local openam_uri = "http://openam.example.com:8080/openam"

      local obj = openam.new(openam_uri, {name = "session"}, {success_url = false})
      local status, json = obj:isTokenValid()
      -- local status, json = obj:authorize()

      if not status == ngx.HTPP_OK then
        -- do something
        -- e.g. ngx.redirect(...), ngx.exit(...)
      end
    ';
    # proxy_pass/to/somewhere/...
  }

  location /logout.html {
    access_by_lua '

      local openam = require "openam"
      local openam_uri = "http://openam.example.com:8080/openam"

      local obj = openam.new(openam_uri, {name = "session"})
      local status, json = obj:logout()

      -- do something
      -- e.g. ngx.redirect(...), ngx.exit(...)
      -- session cookie removed in the http response
    ';
    # proxy_pass/to/somewhere/...
  }

  location /resource.html {
    access_by_lua '

      local openam = require "openam"
      local openam_uri = "http://openam.example.com:8080/openam"

      local obj = openam.new(openam_uri, {name = "session"})
      local status, json = obj:readIdentity("my_login")

      if not status == ngx.HTPP_OK then
        -- do something
        -- e.g. ngx.redirect(...), ngx.exit(...)
      end
    ';
    # proxy_pass/to/somewhere/...
  }
}
```

## API

### new

`openam = openam.new(uri, cookie_params?, redirect_params?)`

Creates the openam object. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.

* `uri`: openam URI

The `cookie_params` table accepts the following fields:
* `name`: string, cookie name between your app and nginx, default: `openam_name`
* `openam_name`: string, cookie name between nginx and openam, default: `iplanetDirectoryPro`
* `domain`: string, cookie domain, default: `host`
* `secure`: boolean, cookie secure attribut, default: `false`
* `http_only`: boolean, cookie httpOnly attribut, default: `true`
* `path`: string, cookie path, default: `/`

The `redirect_params` table accepts the following fields:
* `follow_success_url`: boolean, follow success url sent by OpenAM when authentication success, default: `false`
* `follow_failure_url`: boolean, follow failure url sent by OpenAM when authentication failed, default: `false`

### authenticate

`status, json = openam:authenticate(username, password, realm?)`

Authenticate an user. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.<br />
Add a session cookie with the openam token.

* `username`: string, username
* `password`: string, password
* `realm`: string, realm used for authentication, optional

Return:
* `status`: response http status
* `json`: nil if status not equal to 200 or 401 otherwise openam json response

### logout

`status, json = openam:logout(token?)`

Logout an user. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.<br />
Remove the session cookie with the openam token.

* `token`: string, openam token, optional

Return:
* `status`: response http status
* `json`: nil if no response otherwise openam json response

### isTokenValid

`status, json = openam:logout(logout?, token?)`

Check the validity of the token. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.<br />

* `logout`: boolean, call logout if invalid token, optional
* `token`: string, openam token, optional

Return:
* `status`: response http status
* `json`: nil if status not equal to 200 otherwise openam json response

### authorize

`status, json = openam:authorize(uri_value?, token?)`

Check the access to an uri. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.<br />

* `uri_value`: string, uri to check, optional, default: `scheme://host/uri`
* `token`: string, openam token, optional

Return:
* `status`: response http status
* `json`: nil if status not equal to 200 or 401 otherwise openam json response

### readIdentity

`status, json = openam:readIdentity(self, user, fields?, realm?, token?)`

Read an identity. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.<br />

* `user`: string, username
* `fields`: string separate by ',', selected fields, optional
* `realm`: string, user realm, optional
* `token`: string, openam token, optional

Return:
* `status`: response http status
* `json`: nil if status not equal to 200 otherwise openam json response

## Author

Gamaliel Sick

## Licence

The MIT License (MIT)

Copyright (c) 2014 gsick

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
