use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$pwd/t/servroot/html/?.lua;$apicast/src/?.lua;;";
$ENV{TEST_NGINX_HTTP_CONFIG} = "$apicast/http.d/init.conf";
$ENV{TEST_NGINX_APICAST_PATH} = $apicast;
$ENV{APICAST_MODULE} = 'customfoobar';

env_to_nginx(
    'APICAST_MODULE'
);

log_level('warn');
repeat_each(2);
no_root_location();
run_tests();

__DATA__

=== TEST 1: print error when file is missing

--- http_config
  include $TEST_NGINX_HTTP_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
--- must_die
--- request
GET
--- error_log
module 'customfoobar' not found


=== TEST 2: print error on syntax error

--- http_config
  include $TEST_NGINX_HTTP_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
--- must_die
--- request
GET
--- error_log
customfoobar.lua:1: unexpected symbol near 'not'
--- user_files
>>> customfoobar.lua
not valid lua

=== TEST 3: print error on empty file

--- http_config
  include $TEST_NGINX_HTTP_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
--- request
GET
--- error_log
module customfoobar did not return a table but: boolean
--- must_die
--- user_files
>>> customfoobar.lua
