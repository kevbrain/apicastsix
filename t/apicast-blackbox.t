use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# Can't run twice because one of the test checks the contents of the cache, and
# those change between runs (cache miss in first run, cache hit in second).
repeat_each(1);

run_tests();

__DATA__

=== TEST 1: authentication credentials missing
The message is configurable as well as the status.
--- configuration
{
  "services": [
    {
      "backend_version": 1,
      "proxy": {
        "error_auth_missing": "credentials missing!",
        "error_status_auth_missing": 401
      }
    }
  ]
}
--- request
GET /
--- response_body chomp
credentials missing!
--- error_code: 401



=== TEST 2 api backend gets the request
It asks backend and then forwards the request to the api.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
  location / {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend: test
--- error_code: 200
--- error_log
apicast cache miss key: 42:value:usage%5Bhits%5D=2
--- no_error_log
[error]



=== TEST 3: 3scale gets authorization request over HTTPS
--- env eval
(
  'BACKEND_ENDPOINT_OVERRIDE' => '', # disable override by Test::APIcast::Blackbox
  'OPENSSL_VERIFY' => 'true',
  'SSL_CERT_FILE' => 't/fixtures/server.crt',
)
--- configuration random_port env
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "backend": {
          "endpoint": "https://test_backend:$TEST_NGINX_RANDOM_PORT/",
          "host": "localhost"
        },
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend random_port env
listen $TEST_NGINX_RANDOM_PORT ssl;

ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location /transactions/authrep.xml {
  access_by_lua_block {
    assert = require('luassert')
    assert.equal('https', ngx.var.scheme)
    assert.equal('$TEST_NGINX_RANDOM_PORT', ngx.var.server_port)
    assert.equal('localhost', ngx.var.ssl_server_name)
  }

  content_by_lua_block {
    local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
    require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    ngx.log(ngx.INFO, '3scale backed authorization successful')
  }
}
--- upstream
  location / {
     echo -n 'yay, api backend: $http_host';
  }
--- request eval
['GET /?user_key=value', 'GET /?user_key=value']
--- response_body eval
['yay, api backend: test', 'yay, api backend: test']
--- error_code eval
[ 200, 200 ]
--- error_log
3scale backed authorization successful
--- no_error_log
[error]
--- user_files fixture=tls.pl eval
