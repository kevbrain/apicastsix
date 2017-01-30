# Custom Module

Module is something, that is executed in each nginx phase: init, init_worker, rewrite, access, content, log, post_action, balancer, header_filter, body_filter, ...
It handles processing of each request. There can be only ONE module that is being executed.

The name of the module that is executed is defined by environment variable `APICAST_MODULE` and defaults to `apicast`. 

This example implements a module that extends apicast default one and adds more logging.

## Starting the gateway

```sh
APICAST_MODULE=$(pwd)/verbose.lua ../../bin/apicast -c $(pwd)/../configuration/local.json
```

This starts apicast with module `verbose.lua` instead of the default [`apicast.lua`](https://github.com/3scale/apicast/blob/master/apicast/src/apicast.lua). Using local configuration  so no 3scale account is needed.

## Testing

```sh
curl 'localhost:8080?user_key=foo'
```

And see in the apicast output:

```
2016/11/16 16:52:00 [warn] 98009#0: *5 [lua] verbose.lua:7: call(): upstream response time: 0.001 upstream connect time: 0.000 while logging request, client: 127.0.0.1, server: _, request: "GET /?user_key=foo HTTP/1.1", upstream: "http://127.0.0.1:8081/?user_key=foo", host: "echo"
```
