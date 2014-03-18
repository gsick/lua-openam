# The MIT License (MIT)
#
# Copyright (c) 2014 gsick

use lib '/tmp/test/test-nginx/lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 4);

my $pwd = cwd();

our $HttpConfig = qq{
  lua_package_cpath "/usr/lib64/lua/5.1/?.so;;";
  lua_package_path "/usr/lib64/lua/5.1/resty/http/?.lua;$pwd/lib/?.lua;;";
  error_log  /var/log/nginx/error.log debug;

  charset utf-8;
};

$ENV{TEST_NGINX_OPENAM_URI} ||= "http://openam.example.com:8080/openam";
$ENV{TEST_NGINX_OPENAM_USER} ||= "user";
$ENV{TEST_NGINX_OPENAM_PWD} ||= "password";
$ENV{TEST_NGINX_OPENAM_USER_TEST} ||= "testtesttest";
$ENV{TEST_NGINX_OPENAM_PWD_TEST} ||= "testtesttest";
$ENV{TEST_NGINX_OPENAM_URL_AUTHORIZE} ||= "http://...";
$ENV{TEST_NGINX_OPENAM_URL_UNAUTHORIZE} ||= "http://...";

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: should be authorize
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER_TEST", "$TEST_NGINX_OPENAM_PWD_TEST")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:authorize("$TEST_NGINX_OPENAM_URL_AUTHORIZE")

        if not json2.authorize then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
      ';
    }
--- request
GET /a
--- response_body
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 2: should be unauthorize
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER_TEST", "$TEST_NGINX_OPENAM_PWD_TEST")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:authorize("$TEST_NGINX_OPENAM_URL_UNAUTHORIZE")

        if json2.authorize then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
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