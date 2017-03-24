use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;;";
$ENV{TEST_NGINX_HTTP_CONFIG} = "$apicast/http.d/init.conf";
$ENV{TEST_NGINX_APICAST_PATH} = $apicast;
$ENV{APICAST_CONFIGURATION_LOADER} = 'boot';

env_to_nginx(
    'APICAST_CONFIGURATION_LOADER',
    'TEST_NGINX_APICAST_PATH',
    'THREESCALE_CONFIG_FILE'
);

log_level('emerg');
repeat_each(2);
no_root_location();
run_tests();

__DATA__

=== TEST 1: require configuration on boot
should exit with error if there is no configuration
--- http_config
  include $TEST_NGINX_HTTP_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
--- must_die
--- request
GET
--- error_log
failed to load configuration, exiting
