use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: New request to the service.
Set new limit and decrease the limit.
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
        "proxy_rules": [],
        "policy_chain": [
          {
            "name": "apicast.policy.rate_limiting_to_service",
            "configuration":
              {
                "limit": 10,
                "period": 10,
                "service_name": "service_test_1"
              }
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       local assert = require('luassert')
       assert.same(10, ngx.req.get_headers()['X-RateLimit-Limit'])
       assert.same(9, ngx.req.get_headers()['X-RateLimit-Remaining'])
       assert.is_not_nil(ngx.req.get_headers()['X-RateLimit-Reset'])
       ngx.say('yay, api backend')
     }
  }

--- request
GET /?user_key=value
--- response_headers
X-RateLimit-Limit:10
X-RateLimit-Remaining:9
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: Additional request to the service.
Decrease the existing limit.
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
        "proxy_rules": [],
        "policy_chain": [
          {
            "name": "apicast.policy.rate_limiting_to_service",
            "configuration":
              {
                "limit": 10,
                "period": 10,
                "service_name": "service_test_2"
              }
          },
          {
            "name": "apicast.policy.rate_limiting_to_service",
            "configuration":
              {
                "limit": 10,
                "period": 10,
                "service_name": "service_test_2"
              }
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       local assert = require('luassert')
       assert.same(10, ngx.req.get_headers()['X-RateLimit-Limit'])
       assert.same(8, ngx.req.get_headers()['X-RateLimit-Remaining'])
       assert.is_not_nil(ngx.req.get_headers()['X-RateLimit-Reset'])
       ngx.say('yay, api backend')
     }
  }

--- request
GET /?user_key=value
--- response_headers
X-RateLimit-Limit:10
X-RateLimit-Remaining:8
--- error_code: 200
--- no_error_log
[error]

=== TEST 3: Requests are over the limit.
Return 429 code.
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
        "proxy_rules": [],
        "policy_chain": [
          {
            "name": "apicast.policy.rate_limiting_to_service",
            "configuration":
              {
                "limit": 1,
                "period": 10,
                "service_name": "service_test_3"
              }
          },
          {
            "name": "apicast.policy.rate_limiting_to_service",
            "configuration":
              {
                "limit": 1,
                "period": 10,
                "service_name": "service_test_3"
              }
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       local assert = require('luassert')
       assert.same(1, ngx.req.get_headers()['X-RateLimit-Limit'])
       assert.same(0, ngx.req.get_headers()['X-RateLimit-Remaining'])
       assert.is_not_nil(ngx.req.get_headers()['X-RateLimit-Reset'])
       ngx.say('yay, api backend')
     }
  }

--- request
GET /?user_key=value
--- response_headers
X-RateLimit-Limit:1
X-RateLimit-Remaining:0
--- error_code: 429
--- error_log
Requests over the limit.
