use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: 'set' operation in request headers
We test 4 things:
1) Set op with a header that does not exist creates it with the given value.
2) Set op with a header that exists, clears it and sets the given value.
3) Set op with an empty value deletes the header.
4) Check that the headers are received in the upstream but not in the response
   of the original request.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
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
            "name": "apicast.policy.headers",
            "configuration":
              {
                "request":
                  [
                    { "op": "set", "header": "New-Header", "value": "config_value_nh" },
                    { "op": "set", "header": "Existing-Header", "value": "config_value_eh" },
                    { "op": "set", "header": "Header-To-Delete", "value": "" }
                  ]
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
       assert.same('config_value_nh', ngx.req.get_headers()['New-Header'])
       assert.same('config_value_eh', ngx.req.get_headers()['Existing-Header'])
       assert.is_nil(ngx.req.get_headers()['Header-To-Delete'])
       ngx.say('yay, api backend');
     }
  }
--- request
GET /?user_key=value
--- more_headers
Existing-Header: request_value_eh1
Existing-Header: request_value_eh2
Header-To-Delete: request_value_htd
--- response_body
yay, api backend
--- response_headers
New-Header:
Existing-Header:
Header-To-Delete:
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: 'push' operation in request headers
We test 3 things:
1) Push op with a header that does not exist creates it with the given value.
2) Push op with a header that exists, creates a new header with the same name
   and the given value.
3) Check that the headers are received in the upstream but not in the response
   of the original request.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
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
            "name": "apicast.policy.headers",
            "configuration":
              {
                "request":
                  [
                    { "op": "push", "header": "New-Header", "value": "config_value_nh" },
                    { "op": "push", "header": "Existing-Header", "value": "config_value_eh" }
                  ]
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
       assert.same('config_value_nh', ngx.req.get_headers()['New-Header'])
       local existing_header_values = ngx.req.get_headers()['Existing-Header']
       assert.same({ 'request_value_eh1', 'request_value_eh2', 'config_value_eh' },
                   ngx.req.get_headers()['Existing-Header'])
       ngx.say('yay, api backend');
     }
  }
--- request
GET /?user_key=value
--- more_headers
Existing-Header: request_value_eh1
Existing-Header: request_value_eh2
--- response_body
yay, api backend
--- response_headers
New-Header:
Existing-Header:
--- error_code: 200
--- no_error_log
[error]

=== TEST 3: 'add' operation in request headers
We test 3 things:
1) Add op with a header that does not exist, does not change anything.
2) Add op with a header that exists, adds a new header with the same name and
   the given value.
3) Check that the headers are received in the upstream but not in the response
   of the original request.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
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
            "name": "apicast.policy.headers",
            "configuration":
              {
                "request":
                  [
                    { "op": "add", "header": "New-Header", "value": "config_value_nh" },
                    { "op": "add", "header": "Existing-Header", "value": "config_value_eh" }
                  ]
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
       assert.is_nil(ngx.req.get_headers()['New-Header'])
       local existing_header_values = ngx.req.get_headers()['Existing-Header']
       assert.same({ 'request_value_eh1', 'request_value_eh2', 'config_value_eh' },
                   ngx.req.get_headers()['Existing-Header'])
       ngx.say('yay, api backend');
     }
  }
--- request
GET /?user_key=value
--- more_headers
Existing-Header: request_value_eh1
Existing-Header: request_value_eh2
--- response_body
yay, api backend
--- response_headers
Existing-Header:
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: 'set' operation in response headers
We test 3 things:
1) Set op with a header that does not exit creates it with the given value.
2) Set op with a header that exists, clears it and sets the given value.
3) Set op with an empty value clears the header.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
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
            "name": "apicast.policy.headers",
            "configuration":
              {
                "response":
                  [
                    { "op": "set", "header": "New-Header", "value": "config_value_nh" },
                    { "op": "set", "header": "Existing-Header", "value": "config_value_eh" },
                    { "op": "set", "header": "Header-To-Delete", "value": "" }
                  ]
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
       ngx.header['Existing-Header'] = 'upstream_value_eh1, upstream_value_eh2'
       ngx.header['Header-To-Delete'] = 'upstream_value_htd'
       ngx.say('yay, api backend')
     }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- response_headers
New-Header: config_value_nh
Existing-Header: config_value_eh
Header-To-Delete:
--- error_code: 200
--- no_error_log
[error]

=== TEST 5: 'push' operation in response headers
We test 2 things:
1) Push op with a header that does not exist creates it with the given value.
2) Push op with a header that exists, creates a new header with the same name
   and the given value.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
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
            "name": "apicast.policy.headers",
            "configuration":
              {
                "response":
                  [
                    { "op": "push", "header": "New-Header", "value": "config_value_nh" },
                    { "op": "push", "header": "Existing-Header", "value": "config_value_eh" }
                  ]
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
       ngx.header['Existing-Header'] = 'upstream_value_eh'
       ngx.say('yay, api backend')
     }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- response_headers
New-Header: config_value_nh
Existing-Header: upstream_value_eh, config_value_eh
Header-To-Delete:
--- error_code: 200
--- no_error_log
[error]

=== TEST 6: 'add' operation in response headers
We test 3 things:
1) Add op with a header that does not exist, does not change anything.
2) Add op with a header that exists, adds a new header with the same name and
   the given value.
3) Check that the headers are received in the upstream but not in the response
   of the original request.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
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
            "name": "apicast.policy.headers",
            "configuration":
              {
                "response":
                  [
                    { "op": "add", "header": "New-Header", "value": "config_value_nh" },
                    { "op": "add", "header": "Existing-Header", "value": "config_value_eh" }
                  ]
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
       ngx.header['Existing-Header'] = 'upstream_value_eh'
       ngx.say('yay, api backend')
     }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- response_headers
Existing-Header: upstream_value_eh, config_value_eh
New-Header:
--- error_code: 200
--- no_error_log
[error]

=== TEST 7: headers policy without a configuration
Just to make sure that APIcast does not crash when the policy does not have a
configuration.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
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
          { "name": "apicast.policy.headers" }
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
--- request
GET /?user_key=value
--- more_headers
Some-Header: something
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
