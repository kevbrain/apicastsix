use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# Can't run twice because the deprecation msg shows only once per require.
repeat_each(1);

run_tests();

__DATA__

=== TEST 1: deprecation warnings
APIcast should emit deprecation warnings when loading renamed files.
--- configuration
{ "services": [
  { "proxy":
    {  "policy_chain": [
      { "name": "apicast.policy.upstream",
        "configuration": {
          "rules": [{
            "regex": "/",
            "url": "http://test:$TEST_NGINX_SERVER_PORT"
          }]
        }
      }
    ] }
  }
] }
--- upstream
  location /{
    content_by_lua_block {
      require('apicast')
      ngx.exit(200)
    }
  }
--- request
GET /echo?user_key=foo
--- error_code: 200
--- no_error_log
[error]
--- grep_error_log eval: qr/DEPRECATION:[^,]+/
--- grep_error_log_out
DEPRECATION: file renamed - change: require("apicast") to: require("apicast.policy.apicast")


=== TEST 2: deprecation warnings
APIcast should emit deprecation warnings when loading not namespaced code.
--- configuration
{ "services": [
  { "proxy":
    {  "policy_chain": [
      { "name": "apicast.policy.upstream",
        "configuration": {
          "rules": [{
            "regex": "/",
            "url": "http://test:$TEST_NGINX_SERVER_PORT"
          }]
        }
      }
    ] }
  }
] }
--- upstream
  location /{
    content_by_lua_block {
      require('cli')
      ngx.exit(200)
    }
  }
--- request
GET /echo?user_key=foo
--- error_code: 200
--- no_error_log
[error]
--- grep_error_log eval: qr/DEPRECATION:[^,]+/
--- grep_error_log_out
DEPRECATION: when loading apicast code use correct prefix: require("apicast.cli")
