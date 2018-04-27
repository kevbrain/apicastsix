use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{OPENTRACING_TRACER} ||= 'jaeger';

repeat_each(1);
run_tests();


__DATA__
=== TEST 1: OpenTracing
Request passing through APIcast should publish OpenTracing info.
--- configuration
    {
        "services": [
        {
            "proxy": {
            "policy_chain": [
            { "name": "apicast.policy.upstream",
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
--- request
GET /a_path?
--- response_body eval
qr/uber-trace-id: /
--- error_code: 200
--- no_error_log
[error]
--- udp_listen: 6831
--- udp_reply
--- udp_query eval
qr/jaeger.version/
--- wait: 10
