use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: CORS preflight request
Returns 204 and sets the appropriate headers.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "policy_chain": [
          { "name": "apicast.policy.cors" },
          { "name": "apicast.policy.apicast" }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- request
OPTIONS /
--- more_headers
Origin: localhost
Access-Control-Request-Method: GET
--- error_code: 204
--- no_error_log
[error]

=== TEST 2: CORS actual request with default config
This tests a CORS actual (not preflight) request. The only difference with a
non-CORS request is that the CORS headers will be included in the response.
In this test, we are not using a custom config for the CORS policy. This means
that the response will contain the default CORS headers. By default, all of
them (allow-headers, allow-methods, etc.) simply match the headers received in
the request. So for example, if the request sets the 'Origin' header to
'example.com' the response will set 'Access-Control-Allow-Origin' to
'example.com'.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "policy_chain": [
          { "name": "apicast.policy.cors" },
          { "name": "apicast.policy.apicast" }
        ],
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
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- more_headers
Origin: http://example.com
Access-Control-Request-Method: GET
Access-Control-Request-Headers: Content-Type
--- response_body
yay, api backend: test
--- response_headers
Access-Control-Allow-Headers: Content-Type
Access-Control-Allow-Methods: GET
Access-Control-Allow-Origin: http://example.com
Access-Control-Allow-Credentials: true
--- error_code: 200
--- no_error_log
[error]

=== TEST 3: CORS actual request with custom config
This tests a CORS actual (not preflight) request. We use a custom config to set
the CORS headers in the response.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "policy_chain": [
          { "name": "apicast.policy.cors",
            "configuration": { "allow_headers": [ "X-Custom-Header-1", "X-Custom-Header-2" ],
                               "allow_methods": [ "POST", "GET", "OPTIONS" ],
                               "allow_origin" : "*",
                               "allow_credentials": false } },
          { "name": "apicast.policy.apicast" }
        ],
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
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- more_headers
Origin: http://example.com
Access-Control-Request-Method: GET
Access-Control-Request-Headers: Content-Type
--- response_body
yay, api backend: test
--- response_headers
Access-Control-Allow-Headers: X-Custom-Header-1, X-Custom-Header-2
Access-Control-Allow-Methods: POST, GET, OPTIONS
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: false
--- error_code: 200
--- no_error_log
[error]
