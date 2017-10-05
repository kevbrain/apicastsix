use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);
use Crypt::OpenSSL::RSA;

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;$pwd/spec/?.lua;;";
$ENV{TEST_NGINX_BACKEND_CONFIG} = "$apicast/conf.d/backend.conf";
$ENV{TEST_NGINX_UPSTREAM_CONFIG} = "$apicast/http.d/upstream.conf";
$ENV{TEST_NGINX_APICAST_CONFIG} = "$apicast/conf.d/apicast.conf";

$ENV{TEST_NGINX_REDIS_HOST} ||= $ENV{REDIS_HOST} || "127.0.0.1";
$ENV{TEST_NGINX_RESOLVER} ||= `grep nameserver /etc/resolv.conf | awk '{print \$2}' | head -1 | tr '\n' ' '`;

our $rsa = `cat t/fixtures/rsa.pem`;

log_level('debug');
repeat_each(2);
no_root_location();
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
  set $backend_authentication_type 'provider_key';
  set $backend_authentication_value 'fookey';


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
