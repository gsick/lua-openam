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

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: should be valid
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        local status, json = obj:authenticate("$TEST_NGINX_OPENAM_USER", "$TEST_NGINX_OPENAM_PWD")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  json.tokenId)
        local status2, json2 = obj:isTokenValid()

        if not json2.valid then
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

=== TEST 2: should be invalid
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  "AQIC5wM2LY4SfcwPiAWTY3Cuk5xJ65ei_a9OgJ0rjPKdXD8.*AAJTSQACMDEAAlNLABQtMzg4ODM1NjExNTQzODA5MjYwOQ..*")
        local status, json = obj:isTokenValid()

        if json.valid then
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

=== TEST 3: should be invalid and logout
--- http_config eval: $::HttpConfig
--- config
    location /a {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("$TEST_NGINX_OPENAM_URI")

        ngx.req.set_header("Cookie", "iplanetDirectoryPro=" ..  "AQIC5wM2LY4SfcwPiAWTY3Cuk5xJ65ei_a9OgJ0rjPKdXD8.*AAJTSQACMDEAAlNLABQtMzg4ODM1NjExNTQzODA5MjYwOQ..*")
        local status, json = obj:isTokenValid(true)

        if json.result or not json.code then
          ngx.say("something bad happens")
          return
        end

        ngx.exit(status)
      ';
    }
--- request
GET /a
--- response_headers_like
Set-Cookie: (iplanetDirectoryPro=.*)(Expires=Thu, 01-Jan-70 00:00:00 GMT)(.*)
--- response_body
--- error_code: 200
--- no_error_log
[error]
[warn]