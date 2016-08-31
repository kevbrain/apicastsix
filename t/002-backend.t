use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/src/?.lua;;";
};

our $backendConfig = "$pwd/conf.d/backend.conf";

repeat_each(2);
no_root_location();
run_tests();

__DATA__

=== TEST 1: backend
This is just a simple demonstration of the
echo directive provided by ngx_http_echo_module.
--- http_config eval: $::HttpConfig
--- config eval: "include $::backendConfig;"
--- request
GET /
--- response_body
backend endpoint!
--- error_code: 200
