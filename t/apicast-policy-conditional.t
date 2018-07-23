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
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/log",
                    "right_type": "plain"
                  }
                ]
              },
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
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/log",
                    "right_type": "plain"
                  }
                ]
              },
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

=== TEST 3: Combine several operations in the condition
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
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/log",
                    "right_type": "plain"
                  },
                  {
                    "left": "{{ service.id }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "42",
                    "right_type": "plain"
                  }
                ],
                "combine_op": "and"
              },
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

=== TEST 4: conditional policy combined with upstream policy
This test shows that the conditional policy can be used in combination with the
upstream one to change the upstream according to an HTTP request header.
We define the upstream policy so it redirects the request to the upstream
defined in the config below. The echo policy is included at the end of the
chain, so if the test fails, we'll notice because we'll get the answer from the
echo policy instead of our upstream.
--- upstream
  location / {
     echo 'yay, api backend';
  }
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
              "condition": {
                "operations": [
                  {
                    "left": "{{ headers['Upstream'] }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "test_upstream",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "apicast.policy.upstream",
                  "configuration": {
                    "rules": [
                      {
                        "regex": "/",
                        "url": "http://test:$TEST_NGINX_SERVER_PORT"
                      }
                    ]
                  }
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
--- more_headers
Upstream: test_upstream
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
