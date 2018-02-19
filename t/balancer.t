use lib 't';
use Test::APIcast 'no_plan';

$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/*.conf";
$ENV{RESOLVER} = '127.0.1.1:5353';

env_to_nginx(
    'RESOLVER'
);
master_on();
run_tests();

__DATA__

=== TEST 1: round robin does not leak memory
Balancing different hosts does not leak memory.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('resty.balancer.round_robin').cache_size = 1
  }
--- config
  location = /t {
    content_by_lua_block {
      local round_robin = require('resty.balancer.round_robin')
      local balancer = round_robin.new()

      local peers = { hash = ngx.var.request_id, cur = 1,  1, 2 }
      local peer = round_robin.call(peers)

      ngx.print(peer)
    }
  }
--- pipelined_requests eval
[ "GET /t", "GET /t" ]
--- response_body eval
[ "1", "1" ]
