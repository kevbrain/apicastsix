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

=== TEST 2: does not crash with policies that define Liquid values
The Liquid.Template instances of the liquid lib that we are using store the
context when render() is called on them. That means that there are some
elements in the context that reference the context itself. This could result in
an infinite loop if not properly handled.
This test checks that does not happen.
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
          },
          {
            "name": "headers",
            "version": "builtin",
            "configuration": {
              "request": [
                {
                  "op": "push",
                  "header": "SOME-HEADER",
                  "value_type": "liquid",
                  "value": "{{ service.id }}"
                }
              ]
            }
          }
        ],
        "proxy_rules": []
      }
    }
  ]
}

--- request
GET /
--- error_code: 200
--- no_error_log
[error]
