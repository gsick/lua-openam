lua-openam
==========

Lua OpenAM client driver for the nginx [HttpLuaModule](http://wiki.nginx.org/HttpLuaModule).<br />
Use [OpenAM RESTful API](http://openam.forgerock.org/openam-documentation/openam-doc-source/doc/dev-guide/index/chap-rest.html).<br />
It is different than an OpenAM agent.<br />

## Table of Contents

* [Status](#status)
* [Dependencies](#dependencies)
* [Synopsis](#synopsis)
* [API](#api)
    * [new](#new)
    * [authenticate](#authenticate)
    * [logout](#logout)
    * [isTokenValid](#istokenvalid)
    * [authorize](#authorize)
    * [readIdentity](#readidentity)
    * [escape_dn](#escape_dn)
* [Installation](#installation)
    * [Make](#make)
    * [RPM](#rpm)
    * [LuaRocks](#luarocks)
* [Authors](#authors)
* [Licence](#licence)

## Status

0.0.1 released.

## Dependencies

* [lua-cjson](http://www.kyne.com.au/~mark/software/lua-cjson.php)
* [lua-resty-http](https://github.com/pintsized/lua-resty-http)
* [luautf8](https://github.com/starwing/luautf8)

## Synopsis

```nginx
lua_package_cpath "/usr/lib64/lua/5.1/?.so;;";
lua_package_path "/usr/lib64/lua/5.1/resty/http/?.lua;/usr/share/lua/5.1/openam/?.lua;;";

server {

  location /login.html {
    access_by_lua '

      local openam = require "openam"
      local openam_uri = "http://openam.example.com:8080/openam"

      local obj = openam.new(openam_uri, {name = "session"}, {success_url = false})
      local status, json = obj:authenticate("my_login", "my_password")
      
      -- Input can be escaped
      -- local status, json = obj:authenticate(obj:escape_dn("my_login"), obj:escape_dn("my_password"))

      if status == ngx.HTTP_OK then
        -- session cookie added in the http response
        return
      end

      -- do something
      -- e.g. ngx.redirect(...), ngx.exit(...)
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

      if status == ngx.HTTP_OK then
        return
      end

      -- do something
      -- e.g. ngx.redirect(...), ngx.exit(...)
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

      if if status ~= ngx.HTTP_OK then
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

```lua
openam = openam.new(uri, cookie_params?, redirect_params?)
```

Creates the openam object. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.

* `uri`: openam URI

The `cookie_params` table accepts the following fields:
* `name`: string, cookie name between your app and nginx, default: `openam_name` value
* `openam_name`: string, cookie name between nginx and openam, default: `iplanetDirectoryPro`
* `domain`: string, cookie domain, default: `host`
* `secure`: boolean, cookie secure attribut, default: `false`
* `http_only`: boolean, cookie httpOnly attribut, default: `true`
* `path`: string, cookie path, default: `/`

The `redirect_params` table accepts the following fields:
* `follow_success_url`: boolean, follow success url sent by OpenAM when authentication success, default: `false`
* `follow_failure_url`: boolean, follow failure url sent by OpenAM when authentication failed, default: `false`

### authenticate

```lua
status, json = openam:authenticate(username, password, realm?)
```

Authenticate an user.<br />
Add a session cookie with the openam token.

* `username`: string, username
* `password`: string, password
* `realm`: string, realm used for authentication, optional

Return:
* `status`: http status `200` (authenticate) or `401` (invalid password/username), call `ngx.exit` with `HTTP_INTERNAL_SERVER_ERROR` if error
* `json`: openam json response if status `200`, `nil` otherwise

### logout

```lua
status, json = openam:logout(token?)
```

Logout an user.<br />
Remove the session cookie with the openam token.

* `token`: string, openam token, optional

Return:
* `status`: http status `200` (logout), call `ngx.exit` with `HTTP_INTERNAL_SERVER_ERROR` if error
* `json`: openam json response if status `200`, `nil` otherwise

### isTokenValid

```lua
status, json = openam:logout(logout?, token?)
```

Check the validity of the token.<br />

* `logout`: boolean, call logout if invalid token, optional
* `token`: string, openam token, optional

Return:
* `status`: http status `200` (valid or sucess logout) or `401` (invalid), call `ngx.exit` with `HTTP_INTERNAL_SERVER_ERROR` if error
* `json`: json response `{"valid": true|false}` if status `200`, `nil` otherwise

### authorize

```lua
status, json = openam:authorize(uri_value?, token?)
```

Check the access to an uri. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.<br />

* `uri_value`: string, uri to check, optional, default: `scheme://host/uri`
* `token`: string, openam token, optional

Return:
* `status`: response http status
* `json`: nil if status not equal to 200 or 401 otherwise openam json response

### readIdentity

```lua
status, json = openam:readIdentity(user, fields?, realm?, token?)
```

Read an identity. In case of failures, call `ngx.exit` with `HTTP_FORBIDDEN` status.<br />

* `user`: string, username
* `fields`: string separate by `,`, selected fields, optional
* `realm`: string, user realm, optional
* `token`: string, openam token, optional

Return:
* `status`: response http status
* `json`: nil if status not equal to 200 otherwise openam json response

### escape_dn

```lua
result = openam:escape_dn(s)
```

Escape some special LDAP character, prevent LDAP injection

* `s`: string

Return:
* `result`: escaped string

## Installation

Lua OpenAM requires either [Lua](http://www.lua.org) 5.1, Lua 5.2, or
[LuaJIT](http://www.luajit.org) to build.

The build method can be selected from 4 options:

* Make
* RPM: Various Linux distributions
* LuaRocks (http://www.luarocks.org/): POSIX, OSX, Windows

### Make

The included `Makefile` has generic settings.<br />
First, review and update the included makefile to suit your platform (if required).<br />
Next, install the module:

```bash
make install
```

Or install manually into your Lua module directory:

```bash
cp lib/openam/openam.lua $LUA_MODULE_DIRECTORY
```

### RPM

Linux distributions using [RPM](http://rpm.org) can create a package via
the included RPM spec file. Ensure the +rpm-build+ package (or similar)
has been installed.<br />
Build and install the module via RPM:

```bash
rpmbuild -tb 0.0.1.tar.gz
rpm -Uvh $LUA_OPENAM_RPM
```

### LuaRocks

[LuaRocks](http://luarocks.org) can be used to install and manage Lua
modules on a wide range of platforms (including Windows).<br />
First, extract the Lua OpenAM source package.<br />
Next, install the module:

```bash
cd lua-openam-0.0.1
luarocks make
```

## Authors

Gamaliel Sick

## Licence

```
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
```
