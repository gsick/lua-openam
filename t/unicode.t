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
$ENV{TEST_NGINX_OPENAM_USER} ||= "測試測試測試測試";
$ENV{TEST_NGINX_OPENAM_PWD} ||= "測試測試測試測試";

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