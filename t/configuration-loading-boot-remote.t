use lib 't';
use Test::APIcast 'no_plan';

$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/*.conf";

env_to_nginx(
    'TEST_NGINX_APICAST_PATH',
    'THREESCALE_PORTAL_ENDPOINT'
);

master_on();
run_tests();

__DATA__

=== TEST 1: boot load configuration from remote endpoint
should load that configuration and not fail
--- main_config
env THREESCALE_PORTAL_ENDPOINT=http://127.0.0.1:$TEST_NGINX_SERVER_PORT;
env APICAST_CONFIGURATION_LOADER=boot;
env THREESCALE_DEPLOYMENT_ENV=foobar;
env PATH;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location = /t {
  content_by_lua_block {
    local loader = require('apicast.configuration_loader.remote_v2')
    ngx.say(assert(loader:call()))
  }
}

location = /admin/api/services.json {
    echo '{}';
}
--- request
GET /t
--- response_body
{"services":[],"oidc":[]}
--- exit_code: 200


=== TEST 2: lazy load configuration from remote endpoint
should load that configuration and not fail
--- main_config
env THREESCALE_PORTAL_ENDPOINT=http://127.0.0.1:$TEST_NGINX_SERVER_PORT;
env APICAST_CONFIGURATION_LOADER=lazy;
env THREESCALE_DEPLOYMENT_ENV=foobar;
env PATH;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location = /t {
  content_by_lua_block {
    local loader = require('apicast.configuration_loader.remote_v2')
    ngx.say(assert(loader:call('localhost')))
  }
}

location = /admin/api/services.json {
    echo '{}';
}
--- request
GET /t
--- response_body
{"services":[],"oidc":[]}
--- exit_code: 200

=== TEST 3: retrieve config with liquid values
should not fail
--- main_config
env THREESCALE_PORTAL_ENDPOINT=http://127.0.0.1:$TEST_NGINX_SERVER_PORT;
env APICAST_CONFIGURATION_LOADER=boot;
env THREESCALE_DEPLOYMENT_ENV=production;
env PATH;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location = /t {
  content_by_lua_block {
    local loader = require('apicast.configuration_loader.remote_v2')
    ngx.say(assert(loader:call()))
  }
}

location = /admin/api/services.json {
    echo '{ "services": [ { "service": { "id": 42 } } ] }';
}

location = /admin/api/services/42/proxy/configs/production/latest.json {
echo '
{
  "proxy_config": {
    "id": 42,
    "version": 1,
    "environment": "production",
    "content": {
      "proxy": {
        "hosts": [
          "127.0.0.1"
        ],
        "policy_chain": [
          {
            "name": "headers",
            "version": "builtin",
            "configuration": {
              "request": [
                {
                  "op": "set",
                  "header": "New-Header",
                  "value": "{{ service.id }}",
                  "value_type": "liquid"
                }
              ]
            }
          }
        ],
        "proxy_rules": []
      }
    }
  }
}
';
}
--- request
GET /t
--- exit_code: 200

=== TEST 4: retrieve config with liquid values using THREESCALE_PORTAL_ENDPOINT with path
should not fail
--- main_config
env THREESCALE_PORTAL_ENDPOINT=http://127.0.0.1:$TEST_NGINX_SERVER_PORT/config;
env APICAST_CONFIGURATION_LOADER=boot;
env THREESCALE_DEPLOYMENT_ENV=production;
env PATH;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location = /t {
  content_by_lua_block {
    local loader = require('apicast.configuration_loader.remote_v2')
    ngx.say(assert(loader:call()))
  }
}

location = /config/production.json {
echo '
{
  "proxy_configs": [
    {
      "proxy_config": {
        "id": 42,
        "version": 1,
        "environment": "production",
        "content": {
          "proxy": {
            "hosts": [
              "127.0.0.1"
            ],
            "policy_chain": [
              {
                "name": "headers",
                "version": "builtin",
                "configuration": {
                  "request": [
                    {
                      "op": "set",
                      "header": "New-Header",
                      "value": "{{ service.id }}",
                      "value_type": "liquid"
                    }
                  ]
                }
              }
            ],
            "proxy_rules": []
          }
        }
      }
    }
  ]
}

';
}
--- request
GET /t
--- exit_code: 200

=== TEST 5: load a config where only some of the services have an OIDC configuration
This is a regression test. APIcast crashed when loading a config where only
some of the services used OIDC.
The reason is that we created an array of OIDC configs with
size=number_of_services. Let's say we have 100 services and only the 50th has an
OIDC config. In this case, we created this Lua table:
{ [50] = oidc_config_here }.
The problem is that cjson raises an error when trying to convert a sparse array
like that into JSON. Using the default cjson configuration, the minimum number
of elements to reproduce the error is 11. So in this test, we create 11 services
and assign an OIDC config only to the last one. Check
https://www.kyne.com.au/~mark/software/lua-cjson-manual.html#encode_sparse_array
for more details.
Now we assign to _false_ the elements of the array that do not have an OIDC
config, so this test should not crash.
--- main_config
env THREESCALE_PORTAL_ENDPOINT=http://127.0.0.1:$TEST_NGINX_SERVER_PORT;
env APICAST_CONFIGURATION_LOADER=boot;
env THREESCALE_DEPLOYMENT_ENV=production;
env PATH;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location = /t {
  content_by_lua_block {
    local loader = require('apicast.configuration_loader.remote_v2')
    ngx.say(assert(loader:call()))
  }
}

location = /admin/api/services.json {
    echo '
    {
      "services":[
        { "service": { "id":1 } },
        { "service": { "id":2 } },
        { "service": { "id":3 } },
        { "service": { "id":4 } },
        { "service": { "id":5 } },
        { "service": { "id":6 } },
        { "service": { "id":7 } },
        { "service": { "id":8 } },
        { "service": { "id":9 } },
        { "service": { "id":10 } },
        { "service": { "id":11 } }
      ]
    }';
}

location = /issuer/endpoint/.well-known/openid-configuration {
  content_by_lua_block {
    local base = "http://" .. ngx.var.host .. ':' .. ngx.var.server_port
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode {
        issuer = 'https://example.com/auth/realms/apicast',
        id_token_signing_alg_values_supported = { 'RS256' },
        jwks_uri = base .. '/jwks',
    })
  }
}

location = /jwks {
  content_by_lua_block {
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say([[
        { "keys": [
            { "kty":"RSA","kid":"somekid",
              "n":"sKXP3pwND3rkQ1gx9nMb4By7bmWnHYo2kAAsFD5xq0IDn26zv64tjmuNBHpI6BmkLPk8mIo0B1E8MkxdKZeozQ","e":"AQAB" }
        ] }
    ]])
  }
}

location ~ /admin/api/services/([0-9]|10)/proxy/configs/production/latest.json {
echo '{ "proxy_config": { "content": { } } }';
}
location = /admin/api/services/11/proxy/configs/production/latest.json {
echo '{ "proxy_config": { "content": { "proxy": { "oidc_issuer_endpoint": "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/issuer/endpoint" } } } }';
}
--- request
GET /t
--- exit_code: 200
