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

=== TEST 5: call to backend is cached
First call is done synchronously and the second out of band.
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
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';
  set $backend_authentication_type 'service_token';
  set $backend_authentication_value 'token-value';

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location /api-backend/ {
     echo 'yay, api backend';
  }

  location ~ /test/(.+) {
    proxy_pass $scheme://127.0.0.1:$server_port/$1$is_args$args;
    proxy_set_header Host localhost;
  }

  location = /t {
    echo_subrequest GET /test/one -q user_key=value;
    echo_subrequest GET /test/two -q user_key=value;
  }
--- request
GET /t
--- response_body
yay, api backend
yay, api backend
--- error_code: 200
--- grep_error_log eval: qr/apicast cache (?:hit|miss|write) key: [^,\s]+/
--- grep_error_log_out
apicast cache miss key: 42:value:usage%5Bhits%5D=2
apicast cache write key: 42:value:usage%5Bhits%5D=2
apicast cache hit key: 42:value:usage%5Bhits%5D=2

=== TEST 6: multi service configuration
Two services can exist together and are split by their hostname.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 1,
          backend_version = 1,
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'service-one',
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/one/",
            hosts = { 'one' },
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 1 }
            }
          }
        },
        {
          id = 2,
          backend_version = 2,
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'service-two',
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/two/",
            hosts = { 'two' },
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /transactions/authrep.xml {
    content_by_lua_block {
      if ngx.var.arg_service_id == '1' then
        if ngx.var.arg_service_token == 'service-one' then
         return ngx.exit(200)
       end
     elseif ngx.var.arg_service_id == '2' then
       if ngx.var.arg_service_token == 'service-two' then
         return ngx.exit(200)
       end
     end

     ngx.exit(403)
    }
  }

  location ~ /api-backend(/.+) {
     echo 'yay, api backend: $1';
  }

  location ~ /test/(.+) {
    proxy_pass $scheme://127.0.0.1:$server_port/$1$is_args$args;
    proxy_set_header Host $arg_host;
  }

  location = /t {
    echo_subrequest GET /test/one -q user_key=one-key&host=one;
    echo_subrequest GET /test/two -q app_id=two-id&app_key=two-key&host=two;
  }
--- request
GET /t
--- response_body
yay, api backend: /one/
yay, api backend: /two/
--- error_code: 200
--- no_error_log
[error]
--- grep_error_log eval: qr/apicast cache (?:hit|miss|write) key: [^,\s]+/
--- grep_error_log_out
apicast cache miss key: 1:one-key:usage%5Bhits%5D=1
apicast cache write key: 1:one-key:usage%5Bhits%5D=1
apicast cache miss key: 2:two-id:two-key:usage%5Bhits%5D=2
apicast cache write key: 2:two-id:two-key:usage%5Bhits%5D=2

=== TEST 7: call to backend is cached
First call is done synchronously and the second out of band.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 'oauth',
          proxy = {
            credentials_location = "query",
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';
  set $backend_authentication_type 'service_token';
  set $backend_authentication_value 'token-value';

  location /transactions/oauth_authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location /api-backend/ {
     echo 'yay, api backend';
  }

  location ~ /test/(.+) {
    proxy_pass $scheme://127.0.0.1:$server_port/$1$is_args$args;
    proxy_set_header Host localhost;
  }

  location = /t {
    echo_subrequest GET /test/one -q access_token=value;
    echo_subrequest GET /test/two -q access_token=value;
  }
--- request
GET /t
--- response_body
yay, api backend
yay, api backend
--- error_code: 200
--- grep_error_log eval: qr/apicast cache (?:hit|miss|write) key: [^,\s]+/
--- grep_error_log_out
apicast cache miss key: 42:value:usage%5Bhits%5D=2
apicast cache write key: 42:value:usage%5Bhits%5D=2
apicast cache hit key: 42:value:usage%5Bhits%5D=2
