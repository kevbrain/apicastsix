use lib 't';
use Test::APIcast 'no_plan';

$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/init.conf";
$ENV{APICAST_CONFIGURATION_LOADER} = 'boot';

env_to_nginx(
    'APICAST_CONFIGURATION_LOADER',
    'TEST_NGINX_APICAST_PATH',
    'THREESCALE_CONFIG_FILE'
);

log_level('emerg');
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
