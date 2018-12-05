use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: standalone accepts configuration
--- environment_file: standalone
--- configuration_format: yaml
--- configuration
server:
  listen:
  - port: $TEST_NGINX_SERVER_PORT
    name: test
routes:
  - name: test
    match:
      uri_path: /t
      server_port: test
    destination:
      service: echo
internal:
- name: echo
  policy_chain:
  - policy: apicast.policy.echo
--- request
GET /t
--- response_body
GET /t HTTP/1.1
--- error_code: 200
--- no_error_log
[error]
[warn]
