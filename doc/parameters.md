# APIcast parameters

APIcast v2 has a number of parameters configured as [environment variables](#environment-variables) that can modify the behavior of the gateway. The following reference provides descriptions of these parameters.

Note that when deploying APIcast v2 with OpenShift, some of thee parameters can be configured via OpenShift template parameters. The latter can be consulted directly in the [template](https://raw.githubusercontent.com/3scale/apicast/master/openshift/apicast-template.yml).

## Environment variables

### `APICAST_CUSTOM_CONFIG`

Defines the name of the Lua module that implements custom logic overriding the existing APIcast logic.

### `APICAST_LOG_FILE`

**Default:** _stderr_

Defines the file that will store the OpenResty error log. It is used by `bin/apicast` in the `error_log` directive. Refer to [NGINX documentation](http://nginx.org/en/docs/ngx_core_module.html#error_log) for more information. The file pathcan be either absolute, or relative to the prefix directory (`apicast` by default) 

### `APICAST_LOG_LEVEL`

**Values:** debug | info | notice | warn | error | crit | alert | emerg  
**Default:** warn

Specifies the log level for the OpenResty logs.

### `APICAST_CONFIGURATION_LOADER`

**Values:** boot | lazy  
**Default:** lazy

Defines how to load the configuration.
Boot will require configuration when the gateway starts.
Lazy will load it on demand on incoming request.

### `APICAST_BACKEND_CACHE_HANDLER`

**Values:** strict | resilient
**Default:** strict

Defines how the authorization cache behaves when backend is unavailable.
Strict will remove cached application when backend is unavailable.
Resilient will do so only on getting authorization denied from backend.

### `APICAST_MODULE`

**Default:** "apicast"

Specifies the name of the main Lua module that implements the API gateway logic. Custom modules can override the functionality of the default `apicast.lua` module. See [an example](../examples/custom-module) of how to use modules.

### `APICAST_PATH_ROUTING_ENABLED`

**Values:**
- `true` or `1` for _true_
- `false`, `0` or empty for _false_

When this parameter is set to _true_, the gateway will use path-based routing instead of the default host-based routing.

### `APICAST_RESPONSE_CODES`

**Values:**
- `true` or `1` for _true_
- `false`, `0` or empty for _false_

**Default:** \<empty\> (_false_)

When set to _true_, APIcast will log the response code of the response returned by the API backend in 3scale. In some plans this information can later be consulted from the 3scale admin portal.
Find more information about the Response Codes feature on the [3scale support site](https://support.3scale.net/docs/analytics/response-codes-tracking).

### `APICAST_SERVICES`
**Value:** a comma-separated list of service IDs

Used to filter the services configured in the 3scale API Manager, and only use the configuration for specific services in the gateway, discarding those services IDs of which are not specified in the list.
Service IDs can be found on the **Dashboard > APIs** page, tagged as _ID for API calls_.

### `APICAST_CONFIGURATION_CACHE`

**Values:** _a number > 60_  
**Default:** 0

Specifies the interval (in seconds) that will be the configuration stored for. The value should be set to 0 or more than 60. For example, if `APICAST_CONFIGURATION_CACHE` is set to 120, the gateway will reload the configuration every 2 minutes (120 seconds).

### `REDIS_HOST`

**Default:** "127.0.0.1"

APIcast requires a running Redis instance for OAuth 2.0 flow. `REDIS_HOST` parameter is used to set the hostname of the IP of the Redis instance.

### `REDIS_PORT`

**Default:** 6379

APIcast requires a running Redis instance for OAuth 2.0 flow. `REDIS_PORT` parameter can be used to set the port of the Redis instance.

### `REDIS_URL`

**Default:** no value

APIcast requires a running Redis instance for OAuth 2.0 flow. `REDIS_URL` parameter can be used to set the full URI as DSN format like: `redis://PASSWORD@HOST:PORT/DB`. Takes precedence over `REDIS_PORT` and `REDIS_HOST`.

### `RESOLVER`

Allows to specify a custom DNS resolver that will be used by OpenResty. If the `RESOLVER` parameter is empty, the DNS resolver will be autodiscovered.

### `THREESCALE_DEPLOYMENT_ENV`

**Values:** staging | production
**Default:** production

The value of this environment variable will be used to define the environment for which the configuration will be downloaded from 3scale (Staging or Production), when using new APIcast.

The value will also be used in the header `X-3scale-User-Agent` in the authorize/report requests made to 3scale Service Management API. It is used by 3scale just for statistics.

### `THREESCALE_PORTAL_ENDPOINT`

URI that includes your password and portal endpoint in following format: `<schema>://<password>@<admin-portal-domain>`. The `<password>` can be either the [provider key](https://support.3scale.net/docs/terminology#apikey) or an [access token](https://support.3scale.net/docs/terminology#tokens) for the 3scale Account Management API. `<admin-portal-domain>` is the URL used to log into the admin portal.

**Example**: `https://access-token@account-admin.3scale.net`.

When `THREESCALE_PORTAL_ENDPOINT` environment variable is provided, the gateway will download the configuration from 3scale on initializing. The configuration includes all the settings provided on the Integration page of the API(s).

It is **required** to provide either `THREESCALE_PORTAL_ENDPOINT` or `THREESCALE_CONFIG_FILE` (takes precedence) for the gateway to run successfully.

### `THREESCALE_CONFIG_FILE`

Path to the JSON file with the configuration for the gateway. The configuration can be downloaded from the 3scale admin portal using the URL: `<schema>://<admin-portal-domain>/admin/api/nginx/spec.json` (**Example**: `https://account-admin.3scale.net/admin/api/nginx/spec.json`).

When the gateway is deployed using Docker, the file has to be injected to the docker image as a read only volume, and the path should indicate where the volume is mounted, i.e. path local to the docker container.

You can find sample configuration files in [examples](https://github.com/3scale/apicast/tree/master/examples/configuration) folder.

It is **required** to provide either `THREESCALE_PORTAL_ENDPOINT` or `THREESCALE_CONFIG_FILE` (takes precedence) for the gateway to run successfully.

### `BACKEND_ENDPOINT_OVERRIDE`

URI that overrides backend endpoint from the configuration. Useful when deploying outside OpenShift deployed AMP.

**Example**: `https://backend.example.com`.

### `APICAST_MANAGEMENT_API`

**Values:**

- `disabled`: completely disabled, just listens on the port
- `status`: only the `/status/` endpoints enabled for health checks
- `debug`: full API is open

The [Management API](./management-api.md) is powerful and can control the APIcast configuration.
You should enable the debug level only for debugging.

### `APICAST_SERVICE_${ID}_CONFIGURATION_VERSION`

Replace `${ID}` with the actual Service ID. The value should be the configuration version you can see in the configuration history on the Admin Portal.

Setting it to particual version will make it not auto-update and always use that version.

### `OPENSSL_VERIFY`

**Values:**
- `0`, `false`: disable peer verification
- `1`, `true`: enable peer verification

Controls the OpenSSL Peer Verification. It is off by default, because OpenSSL can't use system certificate store.
It requires custom certificate bundle and adding it to trusted certificates.

It is recommended to use https://github.com/openresty/lua-nginx-module#lua_ssl_trusted_certificate and point to to
certificate bundle generated by [export-builtin-trusted-certs](https://github.com/openresty/openresty-devel-utils/blob/master/export-builtin-trusted-certs).
