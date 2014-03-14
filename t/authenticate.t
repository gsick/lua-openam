# The MIT License (MIT)
#
# Copyright (c) 2014 gsick

use lib '/tmp/test/test-nginx/lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 5);

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
$ENV{TEST_NGINX_OPENAM_PWD_TEST} ||= "testtesttest";

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

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

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

=== TEST 2: should not authenticate without user
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate(nil, "$TEST_NGINX_OPENAM_PWD")

        if json.tokenId then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
    ';
    }
--- request
GET /a
--- raw_response_headers_unlike: Set-Cookie:.*
--- response_body_like chop
^(.*)(401 Authorization Required)(.*)$
--- error_code: 401
--- no_error_log
[error]
[warn]

=== TEST 3: should not authenticate without password
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", nil)

        if json.tokenId then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
    ';
    }
--- request
GET /a
--- raw_response_headers_unlike: Set-Cookie:.*
--- response_body_like chop
^(.*)(401 Authorization Required)(.*)$
--- error_code: 401
--- no_error_log
[error]
[warn]

=== TEST 4: should not authenticate without user and password
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate(nil, nil)

        if json.tokenId then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
    ';
    }
--- request
GET /a
--- raw_response_headers_unlike: Set-Cookie:.*
--- response_body_like chop
^(.*)(401 Authorization Required)(.*)$
--- error_code: 401
--- no_error_log
[error]
[warn]

=== TEST 5: should not authenticate without openam
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("http://127.0.0.1/openam")

        local status, json = obj:authenticate(nil, nil)

        if json.tokenId then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
    ';
    }
--- request
GET /a
--- raw_response_headers_unlike: Set-Cookie:.*
--- response_body_like chop
^(.*)(500 Internal Server Error)(.*)$
--- error_code: 500
--- no_error_log
[error]
[warn]

=== TEST 6: should authenticate in a realm
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER_TEST", "$TEST_NGINX_OPENAM_PWD_TEST", "$TEST_NGINX_OPENAM_REALM")

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

=== TEST 7: should not authenticate in a realm
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD", "$TEST_NGINX_OPENAM_REALM")

        if json.tokenId then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
    ';
    }
--- request
GET /a
--- raw_response_headers_unlike: Set-Cookie:.*
--- response_body_like chop
^(.*)(401 Authorization Required)(.*)$
--- error_code: 401
--- no_error_log
[error]
[warn]

=== TEST 8: should authenticate (custom cookie name)
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI", {name = "session"})

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

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
Set-Cookie: session=.*
--- response_body
--- error_code: 200
--- no_error_log
[error]
[warn]