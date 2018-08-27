use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# Test::Nginx does not allow to grep access logs, so we redirect them to
# stderr to be able to use "grep_error_log" by setting APICAST_ACCESS_LOG_FILE
$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";

run_tests();

__DATA__

=== TEST 1: Enables access logs when configured to do so
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "enable_access_logs": true
            }
          },
          {
            "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [ { "regex": "/", "url": "http://echo" } ]
              }
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- grep_error_log eval
qr/"GET \W+ HTTP\/1.1" 200/
--- grep_error_log_out
"GET / HTTP/1.1" 200
--- no_error_log
[error]

=== TEST 2: Disables access logs when configured to do so
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "enable_access_logs": false
            }
          },
          {
            "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [ { "regex": "/", "url": "http://echo" } ]
              }
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- grep_error_log eval
qr/"GET \W+ HTTP\/1.1" 200/
--- grep_error_log_out
--- no_error_log
[error]

=== TEST 3: Enables access logs by default when the policy is included
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": { }
          },
          {
            "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [ { "regex": "/", "url": "http://echo" } ]
              }
          }
        ]
      }
    }
  ]
}
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- grep_error_log eval
qr/"GET \W+ HTTP\/1.1" 200/
--- grep_error_log_out
"GET / HTTP/1.1" 200
--- no_error_log
[error]
