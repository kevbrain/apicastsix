use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: single rule that matches
In this test, we provide a rule that matches the request and sets the upstream
to the one we have set up. If this was not working we would notice, because
"api_backend" in the service configuration points to an invalid one.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=uk"
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
        "api_backend": "http://example.com:80/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          { "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [ { "regex": "/", "url": "http://test:$TEST_NGINX_SERVER_PORT" } ]
              }
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- upstream
  location /a_path {
     content_by_lua_block {
       require('luassert').are.equal('GET /a_path?user_key=uk&a_param=a_value HTTP/1.1',
                                     ngx.var.request)
       ngx.say('yay, api backend');
     }
  }
--- request
GET /a_path?user_key=uk&a_param=a_value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: multiple rules that match
In this example, we provide a rule that does not match and two that do.
Rules should be matched in order, so we set the first rule that matches to the
upstream we have set up.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=uk"
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
        "api_backend": "http://example:80/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [
                  { "regex": "/i_dont_match", "url": "http://example.com" },
                  { "regex": "/", "url": "http://test:$TEST_NGINX_SERVER_PORT" },
                  { "regex": "/abc", "url": "http://example.com" }
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
  location /a_path {
     content_by_lua_block {
       require('luassert').are.equal('GET /a_path?user_key=uk&a_param=a_value HTTP/1.1',
                                     ngx.var.request)
       ngx.say('yay, api backend');
     }
  }
--- request
GET /a_path?user_key=uk&a_param=a_value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 3: non-matching rules
In this example, none of the rules match, so the request will go to the
upstream in 'api_backend'.
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=uk"
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
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [
                  { "regex": "/i_dont_match", "url": "http://example.com" },
                  { "regex": "/i_dont_either", "url": "http://example.com" },
                  { "regex": "/nope", "url": "http://example.com" }
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
  location /a_path {
     content_by_lua_block {
       require('luassert').are.equal('GET /a_path?user_key=uk&a_param=a_value HTTP/1.1',
                                     ngx.var.request)
       ngx.say('yay, api backend');
     }
  }
--- request
GET /a_path?user_key=uk&a_param=a_value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: rule that matches contains url with path
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=uk"
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
        "api_backend": "http://example.com",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [
                  {
                    "regex": "/",
                    "url": "http://test:$TEST_NGINX_SERVER_PORT/path_in_the_rule"
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
  location /path_in_the_rule {
     content_by_lua_block {
       require('luassert').are.equal('GET /path_in_the_rule?user_key=uk&a_param=a_value HTTP/1.1',
                                     ngx.var.request)
       ngx.say('yay, api backend');
     }
  }
--- request
GET /some_path?user_key=uk&a_param=a_value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 5: rule that matches a POST request
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=uk"
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
        "api_backend": "http://example.com:80/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          { "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [ { "regex": "/", "url": "http://test:$TEST_NGINX_SERVER_PORT" } ]
              }
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- upstream
  location /a_path {
     content_by_lua_block {
       local luassert = require('luassert')

       luassert.are.equal('POST /a_path HTTP/1.1', ngx.var.request)

       ngx.req.read_body()
       local post_args = ngx.req.get_post_args()
       luassert.are.equal('uk', post_args['user_key'])
       luassert.are.equal('a_value', post_args['a_param'])

       ngx.say('yay, api backend')
     }
  }
--- request
POST /a_path
user_key=uk&a_param=a_value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
