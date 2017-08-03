use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";
$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;;";

require("$pwd/t/dns.pl");

log_level('debug');
repeat_each(2);
no_root_location();
run_tests();


__DATA__

=== TEST 1: resolver

--- http_config
lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location /t {
  rewrite_by_lua_block {
    local resty_resolver = require 'resty.resolver'
    local dns_client = require 'resty.dns.resolver'

    local dns = dns_client:new{ nameservers = { { "127.0.0.1", 1953 } } }
    local resolver = resty_resolver.new(dns)

    local servers = resolver:get_servers('3scale.net')
    servers.answers = nil
    ngx.ctx.upstream = servers
  }

  content_by_lua_block {
    local upstream = {}
    for _,server in ipairs(ngx.ctx.upstream) do
      table.insert(upstream, server)
    end
    ngx.say(require('cjson').encode(upstream))
  }
}
--- udp_listen: 1953
--- udp_reply eval
$::dns->("localhost", "127.0.0.1")
--- request
GET /t
--- response_body
[{"ttl":0,"address":"127.0.0.1"}]
--- error_code: 200


=== TEST 2: balancer

--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";

  upstream upstream {
    server 0.0.0.1:1;

    balancer_by_lua_block {
      local round_robin = require 'resty.balancer.round_robin'

      local balancer = round_robin.new()
      local servers = { { address = '127.0.0.1', port = $TEST_NGINX_SERVER_PORT } }
      local peers = balancer:peers(servers)

      local ok, err = balancer:set_peer(peers)

      if not ok then
        ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
        ngx.log(ngx.ERR, "failed to set current peer: "..err)
        ngx.exit(ngx.status)
      end
    }

    keepalive 32;
  }
--- config
location /api {
  echo 'yay';
}

location /t {
  proxy_pass http://upstream/api;
}
--- request
GET /t
--- response_body
yay
--- error_code: 200

=== TEST 3: resolver + balancer

--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";

  upstream upstream {
    server 0.0.0.1:1;

    balancer_by_lua_block {
      local round_robin = require 'resty.balancer.round_robin'

      local balancer = round_robin.new()
      local peers = balancer:peers(ngx.ctx.upstream)

      local peer, err = balancer:set_peer(peers)

      if not peer then
        ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
        ngx.log(ngx.ERR, "failed to set current peer: "..err)
        ngx.exit(ngx.status)
      end
    }

    keepalive 32;
  }
--- config
location /api {
  echo 'yay';
}

location /t {
  rewrite_by_lua_block {
    local resty_resolver = require 'resty.resolver'
    local dns_client = require 'resty.dns.resolver'

    local dns = dns_client:new{ nameservers = { { "127.0.0.1", 1953 } } }
    local resolver = resty_resolver.new(dns)

    ngx.ctx.upstream = resolver:get_servers('localhost', { port = $TEST_NGINX_SERVER_PORT })
  }

  proxy_pass http://upstream/api;
}
--- udp_listen: 1953
--- udp_reply eval
$::dns->("localhost", "127.0.0.1")
--- request
GET /t
--- response_body
yay
--- error_code: 200
