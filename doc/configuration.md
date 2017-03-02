# Configuration and its persistence

Gateway needs configuration in order to work. It needs it to determine service configuration, hostname, etc.

Gateway can load the configuration from file, API or write it through management API (for debugging purposes).

## Configuration loading

### File

Can be loaded in `init` and `init_worker` before server starts serving requests. 

### API (autoload)

Can't be used in `init` or `init_worker` as cosocket API is not available. Would have to be pushed to background via `ngx.timer.at`.

### Management API

Can push configuration to the gateway via an API. 

## Configuration storage

Gateway needs to cache the configuration somewhere. Possibly even across restarts.

### Global variable

Just not scalable. Disappears on every request with `lua_code_cache off`.

### Shared Memory

Needs to serialize configuration into a string. Does not survive restarts. Size is allocated on boot. Shared across workers.

### LRU Cache (lua-resty-lrucache)

Does not use shared memory, but has eviction algorithm to keep maximum number of items. Local to the worker.

### File

Can survive restart. Still needs some other method to act as cache.

## Multi-tenancy

3scale hosts thousands of gateways for its customers and needs a reasonable way to share resources between them. Multi-tenant deployment of this proxy is the preferred way.

TODO: figure out how to store/load the configuration in multi-tenant way
