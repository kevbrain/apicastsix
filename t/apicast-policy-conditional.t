use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: Conditional policy calls its chain when the condition is true
In order to test this, we define a conditional policy that only runs the
phase_logger policy when the request path is /log.
We know that the policy outputs "running phase: some_phase" for each of the
phases it runs, so we can use that to verify it was executed.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": "request_path == \"/log\"",
              "policy_chain": [
                {
                  "name": "apicast.policy.phase_logger"
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- request
GET /log
--- response_body
GET /log HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
--- error_log chomp
running phase: rewrite

=== TEST 2: Conditional policy does not call its chain when the condition is false
In order to test this, we define a conditional policy that only runs the
phase_logger policy when the request path is /log.
We know that the policy outputs "running phase: some_phase" for each of the
phases it runs, so we can use that to verify that it was not executed.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": "request_path == \"/log\"",
              "policy_chain": [
                {
                  "name": "apicast.policy.phase_logger"
                }
              ]
            }
          },
          {
            "name": "apicast.policy.echo"
          }
        ]
      }
    }
  ]
}
--- request
GET /
--- response_body
GET / HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
running phase: rewrite
