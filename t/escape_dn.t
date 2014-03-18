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

  charset utf-8
};

$ENV{TEST_NGINX_OPENAM_URI} ||= "http://openam.example.com:8080/openam";

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: should be ok
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local s1 = " #  測試,測+\\\\試;測   試\\"測<試>測試測試    "
        local r1 = obj:escape_dn(s1)

        ngx.say(r1)
    ';
    }
--- request
GET /a
--- response_body
\ #  測試\,測\+\\試\;測   試\"測\<試\>測試測試   \ 
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 2: should be ok
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local s1 = "# #  測試,測+\\\\試;測   試\\"測<試>測試測試    "
        local r1 = obj:escape_dn(s1)

        ngx.say(r1)
    ';
    }
--- request
GET /a
--- response_body
\# #  測試\,測\+\\試\;測   試\"測\<試\>測試測試   \ 
--- error_code: 200
--- no_error_log
[error]
[warn]