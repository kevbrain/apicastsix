use lib 't';
use Test::APIcast 'no_plan';

$ENV{TEST_NGINX_LUA_PATH} = "$Test::Nginx::Util::HtmlDir/?.lua;$ENV{TEST_NGINX_LUA_PATH}";
$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/init.conf";

$ENV{APICAST_MODULE} = 'customfoobar';

env_to_nginx(
    'APICAST_MODULE'
);

log_level('warn');
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
