use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;;";
$ENV{TEST_NGINX_UPSTREAM_CONFIG} = "$apicast/http.d/upstream.conf";
$ENV{TEST_NGINX_BACKEND_CONFIG} = "$apicast/conf.d/backend.conf";
$ENV{TEST_NGINX_APICAST_CONFIG} = "$apicast/conf.d/apicast.conf";

log_level('debug');
repeat_each(1); # Can't be two as the second call would hit the cache
no_root_location();
run_tests();

__DATA__

=== TEST 1: resilient backend will keep calls through without backend connection
When backend returns server error the call will be let through.
--- main_config
env APICAST_BACKEND_CACHE_HANDLER=resilient;
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })

    require('proxy').shared_cache():set('42:foo:usage%5Bhits%5D=2', 200)
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(502) }
  }

  location /api-backend/ {
     echo 'yay, api backend';
  }

  location = /t {
    echo_subrequest GET /test/one -q user_key=value;
    echo_subrequest GET /test/two -q user_key=value;
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}" ]
--- error_code eval
[ 200, 200 ]


=== TEST 2: strict backend will remove cache after not successful satus
When backend returns server error the next call will be reauthorized.
--- main_config
env APICAST_BACKEND_CACHE_HANDLER=strict;
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })

    require('proxy').shared_cache():set('42:foo:usage%5Bhits%5D=2', 200)
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(502) }
  }

  location /api-backend/ {
     echo 'yay, api backend';
  }

  location = /t {
    echo_subrequest GET /test/one -q user_key=value;
    echo_subrequest GET /test/two -q user_key=value;
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "nil" ]
--- error_code eval
[ 200, 403 ]
