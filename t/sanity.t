use lib 't';
use Test::APIcast::Blackbox 'no_plan';


run_tests();

__DATA__

=== TEST 1: underscores in headers
HTTP headers with underscores allowed and passed upstream.
--- configuration
{
  "services": [{
    "proxy": {
      "policy_chain": [
        { "name": "apicast.policy.upstream",
          "configuration": { "rules": [ { "regex": "/", "url": "http://echo" } ] } }
      ]
    }
  }]
}
--- request
GET /test
--- more_headers
API_KEY: somekey
--- response_body
GET /test HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
API_KEY: somekey
--- error_code: 200
--- no_error_log
[error]



=== TEST 2 dots in headers
Dots in headers are allowed and passed upstream.
--- configuration
{
  "services": [{
    "proxy": {
      "policy_chain": [
        { "name": "apicast.policy.upstream",
          "configuration": { "rules": [ { "regex": "/", "url": "http://echo" } ] } }
      ]
    }
  }]
}
--- request
GET /test
--- more_headers
Client.ID: someid
--- response_body
GET /test HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
Client.ID: someid
--- error_code: 200
--- no_error_log
[error]
