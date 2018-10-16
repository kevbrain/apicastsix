# Prometheus metrics

| Metric                             | Description                                                      | Type      | Labels                                                 | Policy         |
|------------------------------------|------------------------------------------------------------------|-----------|--------------------------------------------------------|----------------|
| nginx_http_connections             | Number of HTTP connections                                       | gauge     | state(accepted, waiting, etc.)                         | Default        |
| nginx_error_log                    | APIcast errors                                                   | counter   | level(error, warn, notice, etc.)                       | Default        |
| openresty_shdict_capacity          | Capacity of the dictionaries shared between workers              | gauge     | dict(one for every dictionary)                         | Default        |
| openresty_shdict_free_space        | Free space of the dictionaries shared between workers            | gauge     | dict(one for every dictionary)                         | Default        |
| nginx_metric_errors_total          | Number of errors of the Lua library that manages the metrics     | counter   | -                                                      | Default        |
| total_response_time_seconds        | Time needed to sent a response to the client (in seconds)        | histogram | -                                                      | Default        |
| upstream_response_time_seconds     | Response times from upstream servers (in seconds)                | histogram | -                                                      | Default        |
| upstream_status                    | HTTP status from upstream servers                                | counter   | status                                                 | Default        |
| threescale_backend_calls           | Authorize and report requests to the 3scale backend (Apisonator) | counter   | endpoint(authrep, auth, report), status(2xx, 4xx, 5xx) | APIcast        |
| batching_policy_auths_cache_hits   | Hits in the auths cache of the 3scale batching policy            | counter   | -                                                      | 3scale Batcher |
| batching_policy_auths_cache_misses | Misses in the auths cache of the 3scale batching policy          | counter   | -                                                      | 3scale Batcher |
