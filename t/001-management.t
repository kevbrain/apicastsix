use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

$ENV{TEST_NGINX_LUA_PATH} = "$pwd/src/?.lua;;";

$ENV{TEST_NGINX_MANAGEMENT_CONFIG} = "$pwd/conf.d/management.conf";

log_level('debug');
repeat_each(1);
no_root_location();
run_tests();

__DATA__

=== TEST 1: readiness probe with saved configuration
When configuration is saved, readiness probe returns success.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require('provider').configure({ services = { { id = 42 } } })
  }
--- config
include $TEST_NGINX_MANAGEMENT_CONFIG;
--- request
GET /status/ready
--- response_body
{"status":"ready","success":true}
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: readiness probe without configuration
Should respond with error status and a reason.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
include $TEST_NGINX_MANAGEMENT_CONFIG;
--- request
GET /status/ready
--- response_body
{"status":"error","error":"not configured","success":false}
--- error_code: 412
--- no_error_log
[error]

=== TEST 2: readiness probe with 0 services
Should respond with error status and a reason.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('provider').configure({services = { }})
  }
--- config
  include $TEST_NGINX_MANAGEMENT_CONFIG;
--- request
GET /status/ready
--- response_body
{"status":"warning","warning":"no services","success":false}
--- error_code: 412
--- no_error_log
[error]

=== TEST 4: liveness probe returns success
As it is always alive.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
  include $TEST_NGINX_MANAGEMENT_CONFIG;
--- request
GET /status/live
--- response_body
{"status":"live","success":true}
--- error_code: 200
--- no_error_log
[error]

=== TEST 5: config endpoint returns the configuration
Endpoint that dumps the original configuration.

--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";

  init_by_lua_block {
    require('provider').configure({ services = { { id = 42 } } })
  }
--- config
include $TEST_NGINX_MANAGEMENT_CONFIG;
--- request
GET /config
--- response_body
{"services":[{"id":42}]}
--- error_code: 200
--- no_error_log
[error]
