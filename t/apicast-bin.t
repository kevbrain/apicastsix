use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: Empty APICAST_LOG_LEVEL does not crash APIcast.
--- env eval
(
  'APICAST_LOG_LEVEL' => '',
)

--- configuration fixture=echo.json
--- request
GET /
--- error_code: 200
