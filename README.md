lua-openam
==========

Lua OpenAM client driver for the nginx [HttpLuaModule](http://wiki.nginx.org/HttpLuaModule).<br />
Use [OpenAM RESTful API](http://openam.forgerock.org/openam-documentation/openam-doc-source/doc/dev-guide/index/chap-rest.html).<br />
It is different than an OpenAM agent.<br />

## Status

beta

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
