use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: liquid_context_debug policy does not crash
If there's a problem while parsing the context or converting it to JSON, this
will crash.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "liquid_context_debug",
            "configuration": {}
          }
        ],
        "proxy_rules": [
        ]
      }
    }
  ]
}
--- request
GET /
--- error_code: 200
--- no_error_log
[error]
