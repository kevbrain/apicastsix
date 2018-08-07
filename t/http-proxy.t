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



=== TEST 2: Downloading configuration uses http proxy + TLS
--- env eval
(
  "http_proxy" => $ENV{TEST_NGINX_HTTP_PROXY},
  'APICAST_CONFIGURATION' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}",
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_DEPLOYMENT_ENV' => 'production',
)
--- upstream env
location = /admin/api/services.json {
  content_by_lua_block {
    ngx.say([[{ "services": [ { "service": { "id": 1337 } } ] }]])
  }
}

location = /admin/api/services/1337/proxy/configs/production/latest.json {
  content_by_lua_block {
    ngx.say([[ { "proxy_config": { "content": { } } }]])
  }
}
--- test

content_by_lua_block {
  local configuration = require('apicast.configuration_loader').load()
  ngx.log(ngx.DEBUG, 'using test block: ', require('cjson').encode(configuration))
}

--- error_code: 200
--- error_log env
proxy request: GET http://127.0.0.1:$TEST_NGINX_SERVER_PORT/admin/api/services.json HTTP/1.1
proxy request: GET http://127.0.0.1:$TEST_NGINX_SERVER_PORT/admin/api/services/1337/proxy/configs/production/latest.json HTTP/1.1
--- no_error_log
[error]



=== TEST 3: Downloading configuration uses http proxy + TLS
--- env random_port eval
(
  "https_proxy" => $ENV{TEST_NGINX_HTTPS_PROXY},
  'APICAST_CONFIGURATION' => "https://test:$ENV{TEST_NGINX_RANDOM_PORT}",
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_DEPLOYMENT_ENV' => 'production',
)
--- upstream env
listen $TEST_NGINX_RANDOM_PORT ssl;

ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location = /admin/api/services.json {
  content_by_lua_block {
    ngx.say([[{ "services": [ { "service": { "id": 1337 } } ] }]])
  }
}

location = /admin/api/services/1337/proxy/configs/production/latest.json {
  content_by_lua_block {
    ngx.say([[ { "proxy_config": { "content": { } } }]])
  }
}
--- user_files fixture=tls.pl eval
--- test
content_by_lua_block {
  local configuration = require('apicast.configuration_loader').load()
  ngx.log(ngx.DEBUG, 'using test block: ', require('cjson').encode(configuration))
}
--- error_code: 200
--- error_log env
proxy request: CONNECT 127.0.0.1:$TEST_NGINX_RANDOM_PORT
--- no_error_log
[error]
