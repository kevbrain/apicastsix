use lib 't';
use TestAPIcastBlackbox 'no_plan';

repeat_each(1);
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
          { "name": "policy.cors" },
          { "name": "apicast" }
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

=== TEST 2: CORS actual request
This test a CORS actual (not preflight) request. The only difference with a
non-CORS request is that the CORS headers will be included in the response.
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
          { "name": "policy.cors" },
          { "name": "apicast" }
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
--- error_log
apicast cache miss key: 42:value:usage%5Bhits%5D=2
--- no_error_log
[error]
