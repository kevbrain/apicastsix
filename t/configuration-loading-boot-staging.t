use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{THREESCALE_DEPLOYMENT_ENV} = 'staging';
$ENV{APICAST_CONFIGURATION_LOADER} = 'boot';
$ENV{APICAST_CONFIGURATION_CACHE} = '';

filters { configuration => 'fixture=echo.json' };

run_tests();

__DATA__

=== TEST 1: 'boot' config loader in staging deployment env without config cache
Test that APIcast does not crash when using the 'boot' config loader and the
'staging' deployment env without a config cache value.
This is a regression test. APIcast was setting a 0 as the default value for the
config cache which is incompatible with the 'boot' loader method, and it
crashed as a result.
--- configuration
--- request
GET /test
--- response_body
GET /test HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
--- error_code: 200
--- no_error_log
[error]
