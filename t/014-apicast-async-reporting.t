use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;;";
$ENV{TEST_NGINX_UPSTREAM_CONFIG} = "$apicast/http.d/upstream.conf";
$ENV{TEST_NGINX_BACKEND_CONFIG} = "$apicast/conf.d/backend.conf";
$ENV{TEST_NGINX_APICAST_CONFIG} = "$apicast/conf.d/apicast.conf";

$ENV{APICAST_REPORTING_THREADS} = '1';

require("t/dns.pl");

env_to_nginx('APICAST_REPORTING_THREADS');

log_level('debug');
repeat_each(2);
no_root_location();
run_tests();

__DATA__

=== TEST 1: api backend gets the request
It asks backend and then forwards the request to the api.
--- http_config
include $TEST_NGINX_UPSTREAM_CONFIG;
lua_shared_dict api_keys 1m;
lua_package_path "$TEST_NGINX_LUA_PATH";
init_by_lua_block {
  ngx.shared.api_keys:set('42:value:usage%5Bhits%5D=2', 200)
  require('configuration_loader').mock({
    services = {
      {
        id = 42,
        backend_version = 1,
        backend_authentication_type = 'service_token',
        backend_authentication_value = 'token-value',
        proxy = {
          backend = { endpoint = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT" },
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
          }
        }
      }
    }
  })
}
--- config
include $TEST_NGINX_APICAST_CONFIG;

location /transactions/authrep.xml {
  content_by_lua_block {
    local expected = "service_id=42&service_token=token-value&usage%5Bhits%5D=2&user_key=value"
    local args = ngx.var.args
    ngx.log(ngx.INFO, 'backend got ', args, ' expected ', expected)
    if args == expected then
      ngx.exit(200)
    else
      ngx.log(ngx.ERR, expected, ' did not match: ', args)
      ngx.exit(403)
    end
  }
}

location /api-backend/ {
  echo 'yay, api backend: $http_host';
}
--- request
GET /?user_key=value
--- response_body
yay, api backend: 127.0.0.1
--- error_code: 200
--- error_log
backend got service_id=42&service_token=token-value&usage%5Bhits%5D=2&user_key=value
--- no_error_log
[error]

=== TEST 2: https api backend works
with async background reporting

--- http_config
include $TEST_NGINX_UPSTREAM_CONFIG;
lua_package_path "$TEST_NGINX_LUA_PATH";
init_by_lua_block {
  ngx.shared.api_keys:set('42:foo:usage%5Bhits%5D=1', 200)
  require('configuration_loader').mock({
    services = {
      {
        id = 42,
        backend_version = 1,
        backend_version = 1,
        backend_authentication_type = 'service_token',
        backend_authentication_value = 'token-value',
        proxy = {
          backend = { endpoint = "https://127.0.0.1:1953" },
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/",
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 1 }
          }
        }
      }
    }
  })
}
lua_shared_dict api_keys 1m;
--- config
include $TEST_NGINX_APICAST_CONFIG;
listen 1953 ssl;

ssl_certificate ../html/server.crt;
ssl_certificate_key ../html/server.key;

location /api/ {
  echo "api response";
}

location /transactions/authrep.xml {
  content_by_lua_block {
    ngx.log(ngx.INFO, 'backend got: ', ngx.var.args)
    ngx.exit(200)
  }
}
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIB0DCCAXegAwIBAgIJAISY+WDXX2w5MAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTYxMjIzMDg1MDExWhcNMjYxMjIxMDg1MDExWjBFMQsw
CQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhkmo
6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1cbx0wVEzbYK5wRb7U
iWhvvvYDltIzsD75vqNQME4wHQYDVR0OBBYEFOBBS7ZF8Km2wGuLNoXFAcj0Tz1D
MB8GA1UdIwQYMBaAFOBBS7ZF8Km2wGuLNoXFAcj0Tz1DMAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDRwAwRAIgZ54vooA5Eb91XmhsIBbp12u7cg1qYXNuSh8zih2g
QWUCIGTHhoBXUzsEbVh302fg7bfRKPCi/mcPfpFICwrmoooh
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIFCV3VwLEFKz9+yTR5vzonmLPYO/fUvZiMVU1Hb11nN8oAoGCCqGSM49
AwEHoUQDQgAEhkmo6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1c
bx0wVEzbYK5wRb7UiWhvvvYDltIzsD75vg==
-----END EC PRIVATE KEY-----
--- request
GET /test?user_key=foo
--- no_error_log
[error]
--- response_body
api response
--- error_code: 200
--- error_log
backend client uri: https://127.0.0.1:1953/transactions/authrep.xml?service_id=42&service_token=token-value&usage%5Bhits%5D=1&user_key=foo ok: true status: 200

=== TEST 3: uses endpoint host as Host header
when connecting to the backend
--- main_config
env RESOLVER=127.0.0.1:1953;
--- http_config
include $TEST_NGINX_UPSTREAM_CONFIG;
lua_package_path "$TEST_NGINX_LUA_PATH";
lua_shared_dict api_keys 1m;
init_by_lua_block {
  ngx.shared.api_keys:set('42:val:usage%5Bhits%5D=2', 200)
  require('configuration_loader').mock({
    services = {
      {
        id = 42,
        backend_version = 1,
        backend_authentication_type = 'service_token',
        backend_authentication_value = 'service-token',
        proxy = {
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/",
          backend = {
            endpoint = 'http://localhost.example.com:$TEST_NGINX_SERVER_PORT'
          },
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
          }
        }
      },
    }
  })
}
--- config
include $TEST_NGINX_APICAST_CONFIG;

location /api/ {
  echo "all ok";
}

location /transactions/authrep.xml {
  content_by_lua_block {
    if ngx.var.host == 'localhost.example.com' then
      ngx.exit(200)
    else
      ngx.log(ngx.ERR, 'invalid host: ', ngx.var.host)
      ngx.exit(404)
    end
  }
}

--- request
GET /t?user_key=val
--- response_body
all ok
--- error_code: 200
--- udp_listen: 1953
--- udp_reply eval
$::dns->("localhost.example.com", "127.0.0.1")
--- no_error_log
[error]
--- error_log
backend client uri: http://localhost.example.com:1984/transactions/authrep.xml?service_id=42&service_token=service-token&usage%5Bhits%5D=2&user_key=val ok: true status: 200
