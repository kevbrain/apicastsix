use lib 't';
use TestAPIcastBlackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: authentication credentials missing
The message is configurable as well as the status.
--- configuration
{
  "services": [
    {
      "backend_version": 1,
      "proxy": {
        "error_auth_missing": "credentials missing!",
        "error_status_auth_missing": 401
      }
    }
  ]
}
--- request
GET /
--- response_body chomp
credentials missing!
--- error_code: 401
