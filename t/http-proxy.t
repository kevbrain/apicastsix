use lib 't';
use Test::APIcast::Blackbox 'no_plan';

require("t/http_proxy.pl");

repeat_each(3);

run_tests();

__DATA__


=== TEST 1: APIcast works when NO_PROXY is set
It connects to backened and forwards request to the upstream.
--- env eval
(
  'no_proxy' => '127.0.0.1,localhost',
)
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
--- no_error_log
[error]
