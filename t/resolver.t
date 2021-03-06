use lib 't';
use Test::APIcast 'no_plan';

$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/*.conf";
$ENV{TEST_NGINX_RESOLVER} = '127.0.1.1:5353';

$ENV{TEST_NGINX_RESOLV_CONF} = "$Test::Nginx::Util::HtmlDir/resolv.conf";

master_on();
log_level('warn');
run_tests();

__DATA__

=== TEST 1: uses all resolvers
both RESOLVER env variable and resolvers in resolv.conf should be used.
checking if commented 'nameserver' and 'search' keywords impact on the 
resolv.conf file parsing.
--- main_config
env RESOLVER=$TEST_NGINX_RESOLVER;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_worker_by_lua_block {
    require('resty.resolver').init('$TEST_NGINX_RESOLV_CONF')
  }
--- config
  location = /t {
    content_by_lua_block {
      local nameservers = require('resty.resolver').nameservers()
      ngx.say('nameservers: ', #nameservers, ' ', nameservers[1], ' ', nameservers[2], ' ', nameservers[3])
    }
  }
--- request
GET /t
--- response_body
nameservers: 3 127.0.1.15353 1.2.3.453 4.5.6.753
--- user_files
>>> resolv.conf
# nameserver updated  in comentary
#nameserver updated  in comentary
#comentary nameserver 1.2.3.4
#comentary nameserver
# search updated.example.com  in comentary
#search updated  in comentary
#search nameserver 1.2.3.4
#search nameserver
search localdomain.example.com local #search nameserver
nameserver 1.2.3.4  #search nameserver
nameserver 4.5.6.7  #nameserver search


=== TEST 2: uses upstream peers
When upstream is defined with the same name use its peers.
--- http_config
lua_package_path "$TEST_NGINX_LUA_PATH";
upstream some_name {
  server 1.2.3.4:5678;
  server 2.3.4.5:6789;
}
--- config
  location = /t {
    content_by_lua_block {
      local resolver = require('resty.resolver'):instance()
      local servers = resolver:get_servers('some_name')

      ngx.say('servers: ', #servers)
      for i=1, #servers do
        ngx.say(servers[i].address, ':', servers[i].port)
      end
    }
  }
--- request
GET /t
--- response_body
servers: 2
1.2.3.4:5678
2.3.4.5:6789
--- no_error_log
[error]


=== TEST 3: can have ipv6 RESOLVER
RESOLVER env variable can be IPv6 address
--- main_config
env RESOLVER=[dead::beef]:5353;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_worker_by_lua_block {
    require('resty.resolver').init('$TEST_NGINX_RESOLV_CONF')
  }
--- config
  location = /t {
    content_by_lua_block {
      local nameservers = require('resty.resolver').nameservers()
      ngx.say('nameservers: ', #nameservers, ' ', tostring(nameservers[1]))
    }
  }
--- request
GET /t
--- response_body
nameservers: 1 [dead::beef]:5353
--- user_files
>>> resolv.conf


=== TEST 4: do not duplicate nameserver from RESOLVER
nameservers should not repeat if already configured
--- main_config
env RESOLVER='127.0.1.1:53';
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_worker_by_lua_block {
    require('resty.resolver').init('$TEST_NGINX_RESOLV_CONF')
  }
--- config
  location = /t {
    content_by_lua_block {
      local nameservers = require('resty.resolver').nameservers()
      ngx.say('nameservers: ', #nameservers, ' ', nameservers[1], ' ', nameservers[2])
    }
  }
--- request
GET /t
--- response_body
nameservers: 2 127.0.1.153 1.2.3.453
--- user_files
>>> resolv.conf
nameserver 127.0.1.1
nameserver 1.2.3.4
