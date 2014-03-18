package = "lua-openam"
version = "0.0.1-1"

source = {
    url = "https://github.com/gsick/lua-openam/archive/lua-openam-0.0.1-beta.tar.gz",
    dir = "lua-openam-0.0.1-beta"
}

description = {
    summary = "Lua OpenAM client driver for the nginx HttpLuaModule",
    detailed = [[
        The Lua OpenAM module provides basic functions for OpenAM RESTful API. It features:
        - Authentication / Logout
        - Token validation
        - Authorization
        - Read identity
    ]],
    homepage = "https://github.com/gsick/lua-openam",
    license = "MIT"
}

dependencies = {
    "lua >= 5.1",
}

build = {
    type = "builtin",
    modules = {
        ["openam"] = "lib/openam/openam.lua"
  }
}
