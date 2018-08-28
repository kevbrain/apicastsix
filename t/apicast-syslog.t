use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(3);

run_tests();

__DATA__

=== TEST 1: sends access logs to syslog
--- env random_port eval
(
  'APICAST_ACCESS_LOG_FILE' => "syslog:server=127.0.0.1:$ENV{TEST_NGINX_RANDOM_PORT}",
)
--- configuration fixture=echo.json
--- request
GET /
--- response_body
GET / HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
--- error_code: 200
--- udp_listen random_port env: $TEST_NGINX_RANDOM_PORT
--- udp_query eval: qr{"GET / HTTP/1.1" 200}
--- udp_reply



=== TEST 2: sends error logs to syslog
--- error_log_file env random_port eval
"syslog:server=127.0.0.1:$ENV{TEST_NGINX_RANDOM_PORT}"
--- log_level: emerg
--- configuration
{
  "services": [{
    "proxy": {
      "policy_chain": [
        {
          "name": "apicast.policy.phase_logger",
          "configuration": { "log_level": "emerg" }
        },
        { "name": "apicast.policy.upstream",
          "configuration": { "rules": [ { "regex": "/", "url": "http://echo" } ] } }
      ]
    }
  }]
}
--- request
GET /
--- response_body
GET / HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
--- error_code: 200
--- udp_listen random_port env: $TEST_NGINX_RANDOM_PORT
--- udp_query eval: qr{\[lua\] phase_logger.lua:\d+: running phase: rewrite}
--- udp_reply
