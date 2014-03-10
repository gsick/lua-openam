use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);
plan tests => 2 * repeat_each() * blocks();

my $pwd = cwd();

our $HttpConfig = qq{
  #lua_package_path "$pwd/lib/?.lua;;";
  lua_package_cpath "/usr/lib64/lua/5.1/?.so;;";
  lua_package_path "/usr/lib64/lua/5.1/resty/http/?.lua;/usr/lib64/lua/5.1/openam/?.lua;;";
  error_log  /var/log/nginx/error.log debug;
};

run_tests();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location /foo {
      content_by_lua '
        local openam = require "openam"
        local obj = openam.new("http://openam.example.com:8080/openam", {name = "session"})

        local status, json = obj:authenticate("amadmin", "azerty1234")

        if not status == ngx.HTPP_OK then
          ngx.log(ngx.ERR, err)
          ngx.exit(ngx.HTTP_FORBIDDEN)
        end

        ngx.print("OK")
    ';
    }
--- request
GET /foo
--- response_body
OK
--- no_error_log
[error]
[warn]
