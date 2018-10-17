use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# Can't run twice because of the setup of the cache for the tests.
repeat_each(1);

run_tests();

__DATA__

=== TEST 1: Caching policy configured as resilient
When the cache is configured as 'resilient', cache entries are not deleted when
backend returns a 500 error. This means that if we get a 200, and then
backend fails and starts returning 500, we will still have the 200 cached
and we'll continue authorizing requests.
In order to test this, we configure our backend so the first request returns
200, and all the others 502.
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
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "resilient" }
          },
          {
            "name": "apicast.policy.apicast"
          }
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
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(502)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo", "GET /?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}", "yay, api backend\x{0a}"]
--- error_code eval
[ 200, 200, 200 ]

=== TEST 2: Caching policy configured as strict
When the cache is configured as 'strict', entries are removed when backend
denies the authorization with a 4xx or when it fails with a 5xx.
In order to test this, we use a backend that returns 200 on the first call, and
502 on the rest. We need to test that the first call is authorized, the
second is too because it will be cached, and the third will not be authorized
because the cache was cleared in the second call.
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
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "strict" }
          },
          {
            "name": "apicast.policy.apicast"
          }
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
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(502)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo", "GET /?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}", "Authentication failed"]
--- error_code eval
[ 200, 200, 403 ]

=== TEST 3: Caching disabled
When the cache is configured as 'none', all the authorizations are performed
synchronously.
In order to test this, we configure our backend to authorize even requests, and
deny the odd ones. We need to check that we got a 200 in even requests and an
auth error in the odd ones.
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
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "none" }
          },
          {
            "name": "apicast.policy.apicast"
          }
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
      local test_counter = ngx.shared.test_counter or 0
      if test_counter % 2 == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(502)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "Authentication failed", "yay, api backend\x{0a}", "Authentication failed"]
--- error_code eval
[ 200, 403, 200, 403 ]

=== TEST 4: Caching policy configured as 'allow' with unseen request
When the cache is configured as 'allow', all requests are authorized when
backend returns a 5XX if they do not have a 'denied' entry in the cache.
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
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "allow" }
          },
          {
            "name": "apicast.policy.apicast"
          }
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
      ngx.exit(502)
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /?user_key=uk1", "GET /?user_key=uk1", "GET /?user_key=uk1"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}", "yay, api backend\x{0a}"]
--- error_code eval
[200, 200, 200]

=== TEST 5: Caching policy configured as 'allow' with previously denied request
When the cache is configured as 'allow', requests will be denied if the last
successful request to backend returned 'denied'.
In order to test this, we use a backend that returns 403 on the first call, and
502 on the rest.
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
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "allow" }
          },
          {
            "name": "apicast.policy.apicast"
          }
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
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(403)
      else
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(502)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /?user_key=uk1", "GET /?user_key=uk1", "GET /?user_key=uk1"]
--- response_body eval
["Authentication failed", "Authentication failed", "Authentication failed"]
--- error_code eval
[403, 403, 403]

=== TEST 6: Caching policy placed after the apicast one in the chain
The caching policy should work correctly regardless of his position in the
chain.
To test that, we define the same as in TEST 1, but this time we place the
caching policy after the apicast one.
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
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "resilient" }
          }
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
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(502)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo", "GET /?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}", "yay, api backend\x{0a}"]
--- error_code eval
[ 200, 200, 200 ]
