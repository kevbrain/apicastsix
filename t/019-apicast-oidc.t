use lib 't';
use TestAPIcast 'no_plan';

$ENV{TEST_NGINX_LUA_PATH} = "$TestAPIcast::spec/?.lua;$ENV{TEST_NGINX_LUA_PATH}";
$ENV{TEST_NGINX_REDIS_HOST} ||= $ENV{REDIS_HOST} || "127.0.0.1";
$ENV{TEST_NGINX_RESOLVER} ||= `grep nameserver /etc/resolv.conf | awk '{print \$2}' | head -1 | tr '\n' ' '`;
$ENV{BACKEND_ENDPOINT_OVERRIDE} ||= "http://127.0.0.1:$Test::Nginx::Util::ServerPortForClient/backend";

our $rsa = `cat t/fixtures/rsa.pem`;

env_to_nginx('BACKEND_ENDPOINT_OVERRIDE');

run_tests();

__DATA__

=== TEST 1: verify JWT
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  include $TEST_NGINX_UPSTREAM_CONFIG;
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        { id = 42,
          backend_version = 'oauth',
          backend_authentication_type = 'provider_key',
          backend_authentication_value = 'fookey',

          proxy = {
            authentication_method = 'oidc',
            oidc_issuer_endpoint = 'https://example.com/auth/realms/apicast',
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 1  }
            }
          }
        }
      },
      oidc = {
        {
            issuer = 'https://example.com/auth/realms/apicast',
            config = { public_key = require('fixtures.rsa').pub, openid = { id_token_signing_alg_values_supported = { 'RS256' } } }
        },
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;
  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/backend';

  location /api-backend/ {
    echo "yes";
  }

  location = /backend/transactions/oauth_authrep.xml {
    content_by_lua_block {
      local expected = "provider_key=fookey&service_id=42&usage%5Bhits%5D=1&app_id=appid"
      if ngx.var.args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, 'expected: ' .. expected .. ' got: ' .. ngx.var.args)
        ngx.exit(403)
      end
    }
  }
--- request
GET /test
--- error_code: 200
--- more_headers eval
use JSON::WebToken;
my $jwt = JSON::WebToken->encode({
  aud => 'appid',
  nbf => 0,
  iss => 'https://example.com/auth/realms/apicast',
  exp => time + 10 }, $::rsa, 'RS256');
"Authorization: Bearer $jwt"
--- no_error_log
[error]
