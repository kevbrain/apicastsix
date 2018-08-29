use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# The output varies between requests, so run only once
repeat_each(1);

run_tests();

__DATA__

=== TEST 1: metrics endpoint works
--- configuration
{
}
--- request
GET /metrics
--- more_headers
Host: metrics
--- response_body
# HELP nginx_http_connections Number of HTTP connections
# TYPE nginx_http_connections gauge
nginx_http_connections{state="accepted"} 1
nginx_http_connections{state="active"} 1
nginx_http_connections{state="handled"} 1
nginx_http_connections{state="reading"} 0
nginx_http_connections{state="total"} 1
nginx_http_connections{state="waiting"} 0
nginx_http_connections{state="writing"} 1
# HELP nginx_metric_errors_total Number of nginx-lua-prometheus errors
# TYPE nginx_metric_errors_total counter
nginx_metric_errors_total 0
# HELP openresty_shdict_capacity OpenResty shared dictionary capacity
# TYPE openresty_shdict_capacity gauge
openresty_shdict_capacity{dict="api_keys"} 10485760
openresty_shdict_capacity{dict="batched_reports"} 1048576
openresty_shdict_capacity{dict="batched_reports_locks"} 1048576
openresty_shdict_capacity{dict="cached_auths"} 1048576
openresty_shdict_capacity{dict="configuration"} 10485760
openresty_shdict_capacity{dict="init"} 16384
openresty_shdict_capacity{dict="limiter"} 1048576
openresty_shdict_capacity{dict="locks"} 1048576
openresty_shdict_capacity{dict="prometheus_metrics"} 16777216
# HELP openresty_shdict_free_space OpenResty shared dictionary free space
# TYPE openresty_shdict_free_space gauge
openresty_shdict_free_space{dict="api_keys"} 10412032
openresty_shdict_free_space{dict="batched_reports"} 1032192
openresty_shdict_free_space{dict="batched_reports_locks"} 1032192
openresty_shdict_free_space{dict="cached_auths"} 1032192
openresty_shdict_free_space{dict="configuration"} 10412032
openresty_shdict_free_space{dict="init"} 4096
openresty_shdict_free_space{dict="limiter"} 1032192
openresty_shdict_free_space{dict="locks"} 1032192
openresty_shdict_free_space{dict="prometheus_metrics"} 16662528
--- error_code: 200
--- no_error_log
[error]
