use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: Token introspection request success
Token introspection policy check access token.
--- backend
  location /token/introspection {
    content_by_lua_block {
      ngx.req.read_body()
      local args, err = ngx.req.get_post_args()
      require('luassert').are.equal('testaccesstoken', args.token)
      ngx.say('{"active": true}')
    }
  }
--- configuration

{
  "services": [
    {
      "id": 42,
      "backend_version": "oidc",
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.token_introspection", 
            "configuration": {
              "client_id": "app",
              "client_secret": "appsec",
              "introspection_url": "http://test_backend:$TEST_NGINX_SERVER_PORT/token/introspection"
            }
          }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
        ]
      }
    }
  ]
}
--- upstream
  location /echo {
    content_by_lua_block {
      ngx.say('yay, api backend')
      ngx.exit(200)
    }
  }

--- request
GET /echo
--- more_headers
Authorization: Bearer testaccesstoken
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: Token already revoked.
Token introspection policy return "403 Unauthorized" if access token is already revoked on IdP.
--- backend
  location /token/introspection {
    content_by_lua_block {
      ngx.say('{"active": false}')
    }
  }
--- configuration

{
  "services": [
    {
      "id": 42,
      "backend_version": "oidc",
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.token_introspection", 
            "configuration": {
              "client_id": "app",
              "client_secret": "appsec",
              "introspection_url": "http://test_backend:$TEST_NGINX_SERVER_PORT/token/introspection"
            }
          }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
        ]
      }
    }
  ]
}
--- upstream
  location /echo {
    content_by_lua_block {
      ngx.say('yay, api backend')
      ngx.exit(200)
    }
  }

--- request
GET /echo
--- more_headers
Authorization: Bearer testaccesstoken
--- error_code: 403
--- no_error_log
[error]

=== TEST 3: Token introspection request is failed due to IdP error
Token introspection policy return "403 Unauthorized" if IdP response error status.
--- backend
  location /token/introspection {
    content_by_lua_block {
      ngx.exit(500)
    }
  }
--- configuration

{
  "services": [
    {
      "id": 42,
      "backend_version": "oidc",
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.token_introspection", 
            "configuration": {
              "client_id": "app",
              "client_secret": "appsec",
              "introspection_url": "http://test_backend:$TEST_NGINX_SERVER_PORT/token/introspection"
            }
          }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
        ]
      }
    }
  ]
}
--- upstream
  location /echo {
    content_by_lua_block {
      ngx.say('yay, api backend')
      ngx.exit(200)
    }
  }

--- request
GET /echo
--- more_headers
Authorization: Bearer testaccesstoken
--- error_code: 403
--- no_error_log
[error]
=== TEST 4: Token introspection request is failed with bad response value
Token introspection policy return "403 Unauthorized" if IdP response error status.
--- backend
  location /token/introspection {
    content_by_lua_block {
      ngx.req.read_body()
      local args, err = ngx.req.get_post_args()
      require('luassert').are.equal('testaccesstoken', args.token)
      ngx.say('<html></html>')
    }
  }
--- configuration

{
  "services": [
    {
      "id": 42,
      "backend_version": "oidc",
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.token_introspection",
            "configuration": {
              "client_id": "app",
              "client_secret": "appsec",
              "introspection_url": "http://test_backend:$TEST_NGINX_SERVER_PORT/token/introspection"
            }
          }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
        ]
      }
    }
  ]
}
--- upstream
  location /echo {
    content_by_lua_block {
      ngx.say('yay, api backend')
      ngx.exit(200)
    }
  }

--- request
GET /echo
--- more_headers
Authorization: Bearer testaccesstoken
--- error_code: 403
--- error_log
[error]
