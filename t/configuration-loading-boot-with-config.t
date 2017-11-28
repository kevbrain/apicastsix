use lib 't';
use TestAPIcastBlackbox 'no_plan';

$ENV{APICAST_CONFIGURATION_LOADER} = 'boot';

env_to_nginx(
    'APICAST_CONFIGURATION_LOADER',
);

log_level('warn');
run_tests();

__DATA__

=== TEST 1: require configuration file to exist
should exit when the config file is missing
--- must_die
--- configuration_file
t/servroot/html/config.json
--- error_log
config.json: No such file or directory
--- user_files
>>> wrong.json

=== TEST 2: require valid json file
should exit when the file has invalid json
--- must_die
--- configuration_file
t/servroot/html/config.json
--- error_log
Expected value but found invalid token at character 1
--- user_files
>>> config.json
not valid json

=== TEST 3: empty json file
should continue as empty json is enough
--- configuration_file
t/servroot/html/config.json
--- request
GET
--- error_code: 404
--- user_files
>>> config.json
{}

