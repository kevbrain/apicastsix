use lib 't';
use TestAPIcast 'no_plan';

run_tests();

__DATA__

=== TEST 1: call to backend is cached
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
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'token-value',
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { id = 1, http_method = "GET",
                pattern = "/{env}/video/encode?size={size}&speed=2x",
                metric_system_name = "weeee", delta = 1,
                parameters = { "env" },
                querystring_parameters = { size = "{size}", speed = "2x" }
              }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location /api-backend/ {
     echo 'yay, api backend';
  }
--- request
GET /staging/video/encode?size=100&speed=3x&user_key=foo&speed=2x
--- response_body
yay, api backend
--- error_code: 200

=== TEST 2: mapping rules when POST request has url parms
url params in a POST call are taken into account when matching mapping rules.

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
            api_backend = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/',
            proxy_rules = {
              { pattern = '/foo?bar=baz',
                querystring_parameters = { bar = 'baz' },
                http_method = 'POST',
                metric_system_name = 'bar',
                delta = 7 }
            }
          }
        },
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
POST /foo?bar=baz&user_key=somekey
--- response_body
api response
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?bar=baz
X-3scale-usage: usage%5Bbar%5D=7

=== TEST 3: mapping rules when POST request has body params
request body params in a POST call are taken into account when matching mapping rules.

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
            api_backend = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/',
            proxy_rules = {
              { pattern = '/foo?bar=baz',
                querystring_parameters = { bar = 'baz' },
                http_method = 'POST',
                metric_system_name = 'bar',
                delta = 7 }
            }
          }
        },
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
POST /foo?user_key=somekey
bar=baz
--- response_body
api response
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?bar=baz
X-3scale-usage: usage%5Bbar%5D=7

=== TEST 4: mapping rules when POST request has body params and url params
Both body params and url params are taken into account when matching mapping
rules. When a param is both in the url and the body, the one in the body takes
precedence.

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
            api_backend = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/',
            proxy_rules = {
              { pattern = '/foo?a_param=val1&another_param=val2',
                querystring_parameters = { a_param = 'val1', another_param = 'val2' },
                http_method = 'POST',
                metric_system_name = 'bar',
                delta = 7 }
            }
          }
        },
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
POST /foo?a_param=val3&another_param=val2&user_key=somekey
a_param=val1
--- response_body
api response
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?a_param=val1&another_param=val2
X-3scale-usage: usage%5Bbar%5D=7
