use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;;";
$ENV{TEST_NGINX_HTTP_CONFIG} = "$apicast/http.d/*.conf";
$ENV{TEST_NGINX_APICAST_PATH} = $apicast;
$ENV{RESOLVER} = '127.0.1.1:5353';


env_to_nginx(
    'RESOLVER'
);
master_on();
log_level('warn');
repeat_each(2);
no_root_location();
run_tests();

__DATA__

=== TEST 1: uses all resolvers
both RESOLVER env variable and resolvers in resolv.conf should be used
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('resty.resolver').init(ngx.config.prefix() .. 'html/resolv.conf')
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
nameserver 1.2.3.4
nameserver 4.5.6.7
