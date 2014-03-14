# The MIT License (MIT)
#
# Copyright (c) 2014 gsick

use lib '/tmp/test/test-nginx/lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 4);

my $pwd = cwd();

our $HttpConfig = qq{
  #lua_package_path "$pwd/lib/?.lua;;";
  lua_package_cpath "/usr/lib64/lua/5.1/?.so;;";
  lua_package_path "/usr/lib64/lua/5.1/resty/http/?.lua;/usr/lib64/lua/5.1/openam/?.lua;;";
  error_log  /var/log/nginx/error.log debug;
};

$ENV{TEST_NGINX_OPENAM_URI} ||= "http://openam.example.com:8080/openam";
$ENV{TEST_NGINX_OPENAM_USER} ||= "user";
$ENV{TEST_NGINX_OPENAM_PWD} ||= "password";
$ENV{TEST_NGINX_OPENAM_REALM} ||= "/test";
$ENV{TEST_NGINX_OPENAM_USER_TEST} ||= "testtesttest";

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: should read identity
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local cjson_safe = require "cjson.safe"
        local cjson = cjson_safe.new()

        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:readIdentity("$TEST_NGINX_OPENAM_USER_TEST")

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
\{(.*)\}
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 2: should not found identity
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local cjson_safe = require "cjson.safe"
        local cjson = cjson_safe.new()

        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:readIdentity("user_not_found")

        if json2 then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status2);
      ';
    }
--- request
GET /a
--- response_body_like chop
^(.*)(404 Not Found)(.*)$
--- error_code: 404
--- no_error_log
[error]
[warn]

=== TEST 3: should not read identity
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local cjson_safe = require "cjson.safe"
        local cjson = cjson_safe.new()

        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:readIdentity("user_not_found")

        if json then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status);
      ';
    }
--- request
GET /a
--- response_body_like chop
^(.*)(401 Authorization Required)(.*)$
--- error_code: 401
--- no_error_log
[error]
[warn]

=== TEST 4: should read identity in a realm
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local cjson_safe = require "cjson.safe"
        local cjson = cjson_safe.new()

        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:readIdentity("$TEST_NGINX_OPENAM_USER_TEST", nil, "$TEST_NGINX_OPENAM_REALM")

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
\{(.*)\}
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 5: should read fields identity
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local cjson_safe = require "cjson.safe"
        local cjson = cjson_safe.new()

        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:readIdentity("$TEST_NGINX_OPENAM_USER_TEST", "username,uid", "$TEST_NGINX_OPENAM_REALM")

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
\{\"username\":\"(.*)\",\"uid\":\[\"(.*)\"\]\}
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 6: should read identity (custom cookie name)
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local cjson_safe = require "cjson.safe"
        local cjson = cjson_safe.new()

        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI", {name = "session"})

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

        ngx.req.set_header("Cookie", "session=" ..  json.tokenId)
        local status2, json2 = obj:readIdentity("$TEST_NGINX_OPENAM_USER_TEST")

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
\{(.*)\}
--- error_code: 200
--- no_error_log
[error]
[warn]