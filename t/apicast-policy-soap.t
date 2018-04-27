use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: SOAP action in SOAPAction header
Test that the usage reported to backend is the sum of:
1) Matching the request against the service mapping rules.
2) Matching the SOAP action URI against the mapping rules of the policy.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that hits is 3 (1 in service rules + 2 in the policy rules)
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=3&user_key=uk"
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
          {
            "pattern": "/",
            "http_method": "GET",
            "metric_system_name": "hits",
            "delta": 1
          }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.soap",
            "configuration": {
              "mapping_rules": [
                {
                  "pattern": "/my_soap_action",
                  "metric_system_name": "hits",
                  "delta": 2
                }
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
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /?user_key=uk&a_param=a_value
--- more_headers
SOAPAction: /my_soap_action
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: SOAP action in Content-Type header
Test that the usage reported to backend is the sum of:
1) Matching the request against the service mapping rules.
2) Matching the SOAP action URI against the mapping rules of the policy.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that hits is 3 (1 in service rules + 2 in the policy rules)
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=3&user_key=uk"
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
          {
            "pattern": "/",
            "http_method": "GET",
            "metric_system_name": "hits",
            "delta": 1
          }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.soap",
            "configuration": {
              "mapping_rules": [
                {
                  "pattern": "/my_soap_action",
                  "metric_system_name": "hits",
                  "delta": 2
                }
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
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /?user_key=uk&a_param=a_value
--- more_headers
Content-Type: application/soap+xml;action=/my_soap_action
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 3 SOAP action both in SOAPAction and Content-Type headers
Test that the usage reported to backend is the sum of:
1) Matching the request against the service mapping rules.
2) Matching the SOAP action URI against the mapping rules of the policy.
In this case, the SOAP action URI is the one specified in the Content-Type,
because it takes precedence over the one in the SOAPAction header.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that hits is 3 (1 in service rules + 2 in the policy rules)
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=3&user_key=uk"
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
          {
            "pattern": "/",
            "http_method": "GET",
            "metric_system_name": "hits",
            "delta": 1
          }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.soap",
            "configuration": {
              "mapping_rules": [
                {
                  "pattern": "/in_ctype",
                  "metric_system_name": "hits",
                  "delta": 2
                },
                {
                  "pattern": "/in_soap_action_header",
                  "metric_system_name": "hits",
                  "delta": 3
                }
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
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /?user_key=uk&a_param=a_value
--- more_headers
SOAPAction: /in_soap_action_header
Content-Type: application/soap+xml;action=/in_ctype
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: no SOAP action specified
Test that the usage reported to backend is only the associated with the service
mapping rules.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that hits is 1 (comes from the service mapping rules).
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=1&user_key=uk"
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
          {
            "pattern": "/",
            "http_method": "GET",
            "metric_system_name": "hits",
            "delta": 1
          }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.soap",
            "configuration": {
              "mapping_rules": [
                {
                  "pattern": "/my_soap_action",
                  "metric_system_name": "hits",
                  "delta": 2
                }
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
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /?user_key=uk&a_param=a_value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
