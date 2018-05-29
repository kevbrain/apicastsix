use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: Referrer sent in authrep call when policy after APIcast in the chain
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
        ],
        "policy_chain": [
          { "name": "apicast.policy.apicast" },
          {
            "name": "apicast.policy.3scale_referrer",
            "configuration": {}
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that we're checking that the referrer receive is the one sent
      -- in the 'Referer' header of the query.
      -- We also check that the rest of the params are correct.
      require('luassert').equals('3scale.net', ngx.req.get_uri_args()['referrer'])
      require('luassert').equals('token-value', ngx.req.get_uri_args()['service_token'])
      require('luassert').equals('42', ngx.req.get_uri_args()['service_id'])
      require('luassert').equals('uk', ngx.req.get_uri_args()['user_key'])
      require('luassert').equals('2', ngx.req.get_uri_args()['usage[hits]'])
    }
  }
--- request
GET /?user_key=uk
--- more_headers
Referer: 3scale.net
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: Referrer sent in authrep call when policy before APIcast in the chain
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
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.3scale_referrer",
            "configuration": {}
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that we're checking that the referrer receive is the one sent
      -- in the 'Referer' header of the query.
      -- We also check that the rest of the params are correct.
      require('luassert').equals('3scale.net', ngx.req.get_uri_args()['referrer'])
      require('luassert').equals('token-value', ngx.req.get_uri_args()['service_token'])
      require('luassert').equals('42', ngx.req.get_uri_args()['service_id'])
      require('luassert').equals('uk', ngx.req.get_uri_args()['user_key'])
      require('luassert').equals('2', ngx.req.get_uri_args()['usage[hits]'])
    }
  }
--- request
GET /?user_key=uk
--- more_headers
Referer: 3scale.net
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 3: Referrer header not sent
Check that when the the 3scale_referrer policy is enabled, and the 'Referer'
header is not sent, the rest of the parameters are correctly sent to backend.
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
        ],
        "policy_chain": [
          { "name": "apicast.policy.apicast" },
          {
            "name": "apicast.policy.3scale_referrer",
            "configuration": {}
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that we're checking that the referrer receive is the one sent
      -- in the 'Referer' header of the query.
      -- We also check that the rest of the params are correct.
      require('luassert').equals('token-value', ngx.req.get_uri_args()['service_token'])
      require('luassert').equals('42', ngx.req.get_uri_args()['service_id'])
      require('luassert').equals('uk', ngx.req.get_uri_args()['user_key'])
      require('luassert').equals('2', ngx.req.get_uri_args()['usage[hits]'])
    }
  }
--- request
GET /?user_key=uk
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
