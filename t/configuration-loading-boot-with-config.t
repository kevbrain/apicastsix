use lib 't';
use Test::APIcast::Blackbox 'no_plan';

env_to_apicast(
    'APICAST_CONFIGURATION_LOADER' => 'boot'
);

log_level('warn');
run_tests();

__DATA__

=== TEST 1: require configuration file to exist
should exit when the config file is missing
--- must_die
--- configuration_file env
$TEST_NGINX_SERVER_ROOT/html/config.json
--- error_log
config.json: No such file or directory
--- user_files
>>> wrong.json

=== TEST 2: require valid json file
should exit when the file has invalid json
--- must_die
--- configuration_file env
$TEST_NGINX_SERVER_ROOT/html/config.json
--- error_log
Expected value but found invalid token at character 1
--- user_files
>>> config.json
not valid json

=== TEST 3: empty json file
should continue as empty json is enough
--- configuration_file env
$TEST_NGINX_SERVER_ROOT/html/config.json
--- request
GET
--- error_code: 404
--- user_files
>>> config.json
{}

