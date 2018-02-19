use lib 't';
use Test::APIcast 'no_plan';

run_tests();

__DATA__

=== TEST 1: backend
This is just a simple demonstration of the
echo directive provided by ngx_http_echo_module.
--- config
include $TEST_NGINX_BACKEND_CONFIG;
--- request
GET /transactions/authrep.xml
--- response_body
transactions authrep!
--- error_code: 200
