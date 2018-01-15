use lib 't';
use Test::APIcast 'no_plan';

run_tests();

__DATA__

=== TEST 1: custom policy chain
This test uses the phase logger policy to verify that all of its phases are run
when we use a policy chain that contains it. The policy chain also contains the
normal apicast policy, so we can check that the authorize flow continues
working. Notice that 'post_action' and 'log' are not ran. There's no
post_action defined and log only runs when post_action runs.
init and init_worker are not run either. They are not executed in policies
defined at the service level.

--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('apicast.configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'token-value',
          proxy = {
            policy_chain = { { name = 'apicast.policy.phase_logger' }, { name = 'apicast.policy.apicast' } },
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              {
                http_method = "GET",
                pattern = "/test",
                metric_system_name = "hits",
                delta = 1
              }
            }
          }
        }
      }
    })
  }

--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location /api-backend/ {
     echo 'yay, api backend';
  }
--- request
GET /test?user_key=abc
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
--- error_log chomp
running phase: rewrite
running phase: access
running phase: balancer
running phase: header_filter
running phase: body_filter
running phase: post_action
