# Custom Module

Module is something, that is executed in each nginx phase: init, init_worker, rewrite, access, content, log, post_action, balancer, header_filter, body_filter etc.
It handles processing of each request. There can be only ONE module that is being executed.

The name of the module that is executed is defined by the environment variable `APICAST_MODULE` and defaults to `apicast`. 

The example described in this README implements a module that extends the default `apicast` module and adds more logging.

There is another example of custom module implementation for IP blacklisting in [`blacklist.lua`](blacklist.lua).

## Starting the gateway

```sh
APICAST_MODULE=$(pwd)/verbose.lua ../../bin/apicast -c $(pwd)/../configuration/local.json
```

This starts APIcast with module `verbose.lua` instead of the default [`apicast.lua`](https://github.com/3scale/apicast/blob/master/apicast/src/apicast.lua). Local configuration file is used, so no 3scale account is needed.

## Testing

```sh
curl 'localhost:8080?user_key=foo'
```

And see in the APIcast output:

```
2016/11/16 16:52:00 [warn] 98009#0: *5 [lua] verbose.lua:7: call(): upstream response time: 0.001 upstream connect time: 0.000 while logging request, client: 127.0.0.1, server: _, request: "GET /?user_key=foo HTTP/1.1", upstream: "http://127.0.0.1:8081/?user_key=foo", host: "echo"
```

## Writing a custom module

To honour the module inheritance, but still be able to override some methods from the `apicast` module, you'll
need some clever use of metatables. Here is a recommended skeleton of the module inheritance:

```lua
-- load and initialize the parent module
local apicast = require('apicast').new()

-- _NAME and _VERSION are used in User-Agent when connecting to the Service Management API
local _M = { _VERSION = '0.0', _NAME = 'Example Module' }
-- define a table, that is going to be this module metatable
-- if your table does not define a property, __index is going to get used
-- and so on until there are no metatables to check
-- so in this case the inheritance works like local instance created with _M.new() -> _M -> apicast`
local mt = { __index = setmetatable(_M, { __index = apicast }) }

function _M.new()
  -- this method is going to get called after this file is required
  -- so create a new table for the internal state (global) and set the metatable for inheritance
  return setmetatable({}, mt)
end

-- to run some custom code in the log phase let's override the method
function _M.log()
  ngx.log(ngx.WARN,
    'upstream response time: ', ngx.var.upstream_response_time, ' ',
    'upstream connect time: ', ngx.var.upstream_connect_time)
  -- and the original apicast method should be executed too
  return apicast:log()
end

return _M
```
