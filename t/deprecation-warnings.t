use lib 't';
use TestAPIcastBlackbox 'no_plan';

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
	]
      }
    }
  ]
}
--- request
GET /echo
--- response_body
GET /echo HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
--- grep_error_log eval: qr/DEPRECATION:[^,]+/
--- grep_error_log_out
DEPRECATION: when loading apicast code use correct prefix: require("apicast.policy.echo")
DEPRECATION: file renamed - change: require("apicast") to: require("apicast.policy.apicast")
