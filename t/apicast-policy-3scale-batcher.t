use lib 't';
use Test::APIcast 'no_plan';

# Can't run twice because of the report batches
repeat_each(1);

run_tests();

__DATA__

=== TEST 1: caches successful authorizations
This test checks that the policy caches successful authorizations. To do that,
we define a backend that makes sure that it's called only once.
--- http_config
include $TEST_NGINX_UPSTREAM_CONFIG;
lua_shared_dict cached_auths 1m;
lua_shared_dict batched_reports 1m;
lua_shared_dict batched_reports_locks 1m;
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
          backend = { endpoint = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT" },
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
          },
          policy_chain = {
            { name = 'apicast.policy.3scale_batcher', configuration = {} },
            { name = 'apicast.policy.apicast' }
          }
        }
      }
    }
  })
}
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authorize.xml {
    content_by_lua_block {
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, 'auth should be cached but called backend anyway')
        ngx.exit(502)
      end
    }
  }

  location /api-backend {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}"]
--- error_code eval
[ 200, 200 ]
--- no_error_log
[error]

=== TEST 2: caches unsuccessful authorizations
This test checks that the policy caches successful authorizations. To do that,
we define a backend that makes sure that it's called only once.
--- http_config
include $TEST_NGINX_UPSTREAM_CONFIG;
lua_shared_dict cached_auths 1m;
lua_shared_dict batched_reports 1m;
lua_shared_dict batched_reports_locks 1m;
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
          backend = { endpoint = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT" },
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
          },
          policy_chain = {
            { name = 'apicast.policy.3scale_batcher', configuration = {} },
            { name = 'apicast.policy.apicast' }
          }
        }
      }
    }
  })
}
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authorize.xml {
    content_by_lua_block {
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.header['3scale-rejection-reason'] = 'limits_exceeded'
        ngx.status = 409
        ngx.exit(ngx.HTTP_OK)
      else
        ngx.log(ngx.ERR, 'auth should be cached but called backend anyway')
        ngx.exit(502)
      end
    }
  }

  location /api-backend {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo"]
--- response_body eval
["Limits exceeded", "Limits exceeded"]
--- error_code eval
[ 429, 429 ]
--- no_error_log
[error]

=== TEST 3: batched reports
This test checks that reports are batched correctly. In order to do that, we
make 100 requests using 5 different user keys (20 requests for each of them).
We define 2 services and make each of them receive the same number of calls.
This is to test that reports are correctly classified by service.
At the end, we make another request that is redirected to a location we defined
in this test that checks the counters of the batched reports.
To make sure that the policy does not report the batched reports during the
test, we define a high 'batch_report_seconds' in the policy config.
--- http_config
include $TEST_NGINX_UPSTREAM_CONFIG;
lua_shared_dict cached_auths 1m;
lua_shared_dict batched_reports 1m;
lua_shared_dict batched_reports_locks 1m;
lua_package_path "$TEST_NGINX_LUA_PATH";
init_by_lua_block {
  require('apicast.configuration_loader').mock({
    services = {
      {
        id = 1,
        backend_version = 1,
        backend_authentication_type = 'service_token',
        backend_authentication_value = 'token-value',
        proxy = {
          hosts = { 'one' },
          backend = { endpoint = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT" },
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
          },
          policy_chain = {
            {
              name = 'apicast.policy.3scale_batcher',
              configuration = { batch_report_seconds = 60 }
            },
            { name = 'apicast.policy.apicast' }
          }
        }
      },
      {
        id = 2,
        backend_version = 1,
        backend_authentication_type = 'service_token',
        backend_authentication_value = 'token-value',
        proxy = {
          hosts = { 'two' },
          backend = { endpoint = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT" },
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
          },
          policy_chain = {
            {
              name = 'apicast.policy.3scale_batcher',
              configuration = { batch_report_seconds = 60 }
            },
            { name = 'apicast.policy.apicast' }
          }
        }
      }
    }
  })
}
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /check_batched_reports {
    content_by_lua_block {
      local keys_helper = require('apicast.policy.3scale_batcher.keys_helper')
      local luassert = require('luassert')

      for service = 1,2 do
        for user_key = 1,5 do
          local key = keys_helper.key_for_batched_report(service, {user_key = user_key }, 'hits')
          -- The mapping rule defines a delta of 2 for hits, and we made 10
          -- requests for each {service, user_key}, so all the counters should
          -- be 20.
          luassert.equals(20, ngx.shared.batched_reports:get(key))
        end
      end
    }
  }

  location /transactions/authorize.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }

  location /api-backend {
     echo 'yay, api backend';
  }

--- request eval
my $res = [];

for(my $i = 0; $i < 20; $i = $i + 1 ) {
  push $res, "GET /test?user_key=1";
  push $res, "GET /test?user_key=2";
  push $res, "GET /test?user_key=3";
  push $res, "GET /test?user_key=4";
  push $res, "GET /test?user_key=5";
}

push $res, "GET /check_batched_reports";

$res
--- more_headers eval
my $res = [];

for(my $i = 0; $i < 50; $i = $i + 1 ) {
  push $res, "Host: one";
}

for(my $i = 0; $i < 50; $i = $i + 1 ) {
  push $res, "Host:two";
}

push $res, "Host: one";

$res
--- no_error_log
[error]

=== TEST 4: report batched reports to backend
This test checks that reports are sent correctly to backend. To do that, it performs
some requests, then it forces a report request to backend, and finally, checks that
the POST body that backend receives is correct.
--- http_config
include $TEST_NGINX_UPSTREAM_CONFIG;
lua_shared_dict cached_auths 1m;
lua_shared_dict batched_reports 1m;
lua_shared_dict batched_reports_locks 1m;
lua_package_path "$TEST_NGINX_LUA_PATH";
init_by_lua_block {
  require('apicast.configuration_loader').mock({
    services = {
      {
        id = 1,
        backend_version = 1,
        backend_authentication_type = 'service_token',
        backend_authentication_value = 'token-value',
        proxy = {
          backend = { endpoint = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT" },
          api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
          proxy_rules = {
            { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
          },
          policy_chain = {
            {
              name = 'apicast.policy.3scale_batcher',
              configuration = { batch_report_seconds = 60 }
            },
            { name = 'apicast.policy.apicast' }
          }
        }
      }
    }
  })
}
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /force_report_to_backend {
    content_by_lua_block {
      local ReportsBatcher = require ('apicast.policy.3scale_batcher.reports_batcher')
      local reporter = require ('apicast.policy.3scale_batcher.reporter')
      local http_ng_resty = require('resty.http_ng.backend.resty')
      local backend_client = require('apicast.backend_client')

      local service_id = '1'

      local reports_batcher = ReportsBatcher.new(
        ngx.shared.batched_reports, 'batched_reports_locks')

      local reports = reports_batcher:get_all(service_id)

      local backend = backend_client:new(
        {
          id = '1',
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'token-value',
          backend = { endpoint = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT" }
        }, http_ng_resty)

      reporter.report(reports, service_id, backend, reports_batcher)
    }
  }

  location /transactions/authorize.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }

  location /transactions.xml {
    content_by_lua_block {
     ngx.req.read_body()
     local post_args = ngx.req.get_post_args()

     -- Transactions can be received in any order, so we need to check both
     -- possibilities.
     -- We did 20 requests for each user key, and each request increases
     -- hits by 2 according to the mapping rules defined.
     local order1 =
       (post_args["transactions[0][user_key]"] == '1' and
         post_args["transactions[0][usage][hits]"] == "40") and
       (post_args["transactions[1][user_key]"] == '2' and
         post_args["transactions[1][usage][hits]"] == "40")

     local order2 =
       (post_args["transactions[1][user_key]"] == '1' and
         post_args["transactions[1][usage][hits]"] == "40") and
       (post_args["transactions[0][user_key]"] == '2' and
         post_args["transactions[0][usage][hits]"] == "40")

      local luassert = require('luassert')
      luassert.equals('1', ngx.req.get_uri_args()['service_id'])
      luassert.is_true(order1 or order2)
    }
  }

  location /api-backend {
     echo 'yay, api backend';
  }

--- request eval
my $res = [];

for(my $i = 0; $i < 20; $i = $i + 1 ) {
  push $res, "GET /test?user_key=1";
  push $res, "GET /test?user_key=2";
}

push $res, "GET /force_report_to_backend";

$res
--- no_error_log
[error]
