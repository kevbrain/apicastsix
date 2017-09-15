use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;;";
$ENV{TEST_NGINX_HTTP_CONFIG} = "$apicast/http.d/init.conf";
$ENV{TEST_NGINX_APICAST_PATH} = $apicast;
$ENV{APICAST_CONFIGURATION_LOADER} = 'boot';
$ENV{THREESCALE_CONFIG_FILE} = 't/servroot/html/config.json';

env_to_nginx(
    'APICAST_CONFIGURATION_LOADER',
    'TEST_NGINX_APICAST_PATH',
    'THREESCALE_CONFIG_FILE'
);

log_level('warn');
repeat_each(2);
no_root_location();
run_tests();

__DATA__

=== TEST 1: require configuration file to exist
should exit when the config file is missing
--- http_config
  include $TEST_NGINX_HTTP_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
--- must_die
--- request
GET
--- error_log
config.json: No such file or directory
--- user_files
>>> wrong.json

=== TEST 2: require valid json file
should exit when the file has invalid json
--- http_config
  include $TEST_NGINX_HTTP_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
--- must_die
--- request
GET
--- error_log
Expected value but found invalid token at character 1
--- user_files
>>> config.json
not valid json

=== TEST 3: empty json file
should continue as empty json is enough
--- http_config
  include $TEST_NGINX_HTTP_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
--- request
GET
--- user_files
>>> config.json
{}

