use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: sub operation
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
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
            "name": "apicast.policy.url_rewriting",
            "configuration": {
              "commands": [
                { "op": "sub", "regex": "original", "replace": "new" }
              ]
            }
          }
        ]
      }
    }
  ]
}
--- upstream
  location ~ /xxx_new_yyy$ {
    content_by_lua_block {
      ngx.say('yay, api backend');
    }
  }
--- request
GET /xxx_original_yyy?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: gsub operation
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
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
            "name": "apicast.policy.url_rewriting",
            "configuration": {
              "commands": [
                { "op": "gsub", "regex": "original", "replace": "new" }
              ]
            }
          }
        ]
      }
    }
  ]
}
--- upstream
  location ~ /aaa_new_bbb_new_ccc$ {
    content_by_lua_block {
      ngx.say('yay, api backend');
    }
  }
--- request
GET /aaa_original_bbb_original_ccc?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 3: ordered commands
Substitutions are applied in the order specified.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
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
            "name": "apicast.policy.url_rewriting",
            "configuration": {
              "commands": [
                { "op": "gsub", "regex": "aaa", "replace": "bbb", "options": "i" },
                { "op": "sub", "regex": "bbb", "replace": "ccc" },
                { "op": "sub", "regex": "ccc", "replace": "ddd" }
              ]
            }
          }
        ]
      }
    }
  ]
}
--- upstream
  location ~ /ddd_bbb$ {
    content_by_lua_block {
      ngx.say('yay, api backend');
    }
  }
--- request
GET /aaa_aaa?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: break
We need to test 2 things:
1) A break is only applied when the URL is rewritten.
2) When break is specified in a command, it will be the last one applied.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
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
            "name": "apicast.policy.url_rewriting",
            "configuration": {
              "commands": [
                { "op": "sub", "regex": "does_not_match", "replace": "a", "break": true },
                { "op": "sub", "regex": "aaa", "replace": "bbb" },
                { "op": "sub", "regex": "bbb", "replace": "ccc", "break": true },
                { "op": "sub", "regex": "ccc", "replace": "ddd" }
              ]
            }
          }
        ]
      }
    }
  ]
}
--- upstream
  location ~ /ccc$ {
    content_by_lua_block {
      ngx.say('yay, api backend');
    }
  }
--- request
GET /aaa?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 5: url rewriting policy placed before the apicast one in the chain
The url rewriting policy is placed before the apicast one in the policy chain,
this means that the request will be rewritten before matching the mapping
rules.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
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
          { "pattern": "/new", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.url_rewriting",
            "configuration": {
              "commands": [
                { "op": "sub", "regex": "original", "replace": "new" }
              ]
            }
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- upstream
  location /new {
    content_by_lua_block {
      ngx.say('yay, api backend');
    }
  }
--- request
GET /original?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
