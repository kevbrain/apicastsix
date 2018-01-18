use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: deprecation warnings
APIcast should emit deprecation warnings when loading code using the old paths.
--- configuration
{
  "services": [
    {
      "backend_version": 1,
      "proxy": {
        "policy_chain": [
          { "name": "policy.echo" },
          { "name": "apicast" }
        ],
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
      ngx.exit(200)
    }
  }
--- request
GET /echo?user_key=foo
--- response_body
GET /echo?user_key=foo HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
--- grep_error_log eval: qr/DEPRECATION:[^,]+/
--- grep_error_log_out
DEPRECATION: when loading apicast code use correct prefix: require("apicast.policy.echo")
DEPRECATION: file renamed - change: require("apicast") to: require("apicast.policy.apicast")
