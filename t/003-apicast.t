use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

$ENV{TEST_NGINX_LUA_PATH} = "$pwd/src/?.lua;;";
our $HttpConfig = qq{
    lua_package_path "$pwd/src/?.lua;;";
    init_by_lua_block { require('luarocks.loader') }
};

$ENV{TEST_NGINX_BACKEND_CONFIG} = "$pwd/conf.d/backend.conf";
$ENV{TEST_NGINX_APICAST_CONFIG} = "$pwd/conf.d/apicast.conf";

log_level('debug');
repeat_each(1);
no_root_location();
run_tests();

__DATA__

=== TEST 1: authentication credentials missing
The message is configurable as well as the status.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_auth_missing = 'credentials missing!',
            error_status_auth_missing = 401
          }
        }
      }
    })
  }
--- config
include $TEST_NGINX_BACKEND_CONFIG;
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /
--- response_body chomp
credentials missing!
--- error_code: 401


=== TEST 2: no mapping rules matched
The message is configurable and status also.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_no_match = 'no mapping rules!',
            error_status_no_match = 412
          }
        }
      }
    })
  }
--- config
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /?user_key=value
--- response_body chomp
no mapping rules!
--- error_code: 412

=== TEST 3: authentication credentials invalid
The message is configurable and default status is 403.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_auth_failed = 'credentials invalid!',
            error_status_auth_failed = 402,
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;
  location /transactions/authrep.xml {
    deny all;
  }
--- request
GET /?user_key=value
--- response_body chomp
credentials invalid!
--- error_code: 402
