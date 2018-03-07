use lib 't';
use Test::APIcast::Blackbox 'no_plan';

use Cwd qw(abs_path);

BEGIN {
    $ENV{TEST_NGINX_APICAST_POLICY_LOAD_PATH} = 't/fixtures/policies';
}

env_to_apicast(
    'APICAST_POLICY_LOAD_PATH' => abs_path($ENV{TEST_NGINX_APICAST_POLICY_LOAD_PATH}),
);

run_tests();

__DATA__

=== TEST 1: policy with invalid configuration
In this test, we use an example policy that requires a 'message' param in the
configuration. We are going to initialize the policy with an empty
configuration and check that Apicast exits.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "policy_chain": [
          { "name": "example_policy", "version": "1.0.0", "configuration": { } }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- request
GET /?user_key=value
--- must_die
