# The MIT License (MIT)
#
# Copyright (c) 2014 gsick

use lib '/tmp/test/test-nginx/lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 4) + 1;

my $pwd = cwd();

our $HttpConfig = qq{
  lua_package_cpath "/usr/lib64/lua/5.1/?.so;;";
  lua_package_path "/usr/lib64/lua/5.1/resty/http/?.lua;$pwd/lib/?.lua;;";
  error_log  /var/log/nginx/error.log debug;

  charset utf-8;
};

$ENV{TEST_NGINX_OPENAM_URI} ||= "http://openam.example.com:8080/openam";
$ENV{TEST_NGINX_OPENAM_REALM} ||= "/test";

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: should authenticate and set default session cookie
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("測試測試測試測試", "測試測試測試測試")

        if not json.tokenId then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
    ';
    }
--- request
GET /a
--- response_headers_like
Set-Cookie: iplanetDirectoryPro=.*
--- response_body
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 2: should read identity
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local cjson_safe = require "cjson.safe"
        local cjson = cjson_safe.new()

        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("測試測試測試測試", "測試測試測試測試", "$TEST_NGINX_OPENAM_REALM")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:readIdentity("測試測試測試測試", "username,uid", "$TEST_NGINX_OPENAM_REALM")

        if not json2.username then
          ngx.say("something bad happens")
          return
        end

        ngx.say(cjson.encode(json2))
      ';
    }
--- request
GET /a
--- response_body_like chop
\{\"username\":\"測試測試測試測試\",\"uid\":\[\"測試測試測試測試\"\]\}
--- error_code: 200
--- no_error_log
[error]
[warn]