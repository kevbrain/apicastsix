# Policies examples

The ngx_example policy is setting request header based on the policy configuration.

You can see the APIcast configuration in [examples/policies/example.json](./example.json).
It defines a policy chain with two policies: `ngx_example` and `upstream`.
The `upstream` policy just forwards the request to some upstream server based on its' configuration.
The `ngx_example` policy is configured to set HTTP header `Example` to value `Value`.

You can start example configuration with example policy by running this from the APIcast root directory:

```shell
bin/apicast -c examples/policies/example.json -b --policy-load-path examples/policies -v
```
**To run `bin/apicast` you must install APIcast [tools and dependencies](../../README.md#tools-and-dependencies) first* 

And then make a request by curl:

```shell
curl 'localhost:8080/test'
```

And see a response:

```http
GET /test HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
User-Agent: curl/7.57.0
Accept: */*
Example: Value
```

And see similar line in the APIcast log:

```
2018/02/08 10:01:48 [notice] 72249#10132050: *9 [lua] init.lua:19: op(): setting header: Example to: Value, client: 127.0.0.1, server: _, request: "GET /test HTTP/1.1", host: "localhost:8080"
```

You can see the policy entry point in [examples/policies/ngx-example/1.0.0/init.lua](./ngx-example/1.0.0/init.lua) and the source code in
[examples/policies/ngx-example/1.0.0/ngx_example.lua](./ngx-example/1.0.0/ngx_example.lua) to verify it indeed should print such log entry.

For the policy to be complete it needs a manifest with description and the configuration schema.
The file has to be named [`apicast-policy.json`](./ngx-example/1.0.0/apicast-policy.json) and has
to be valid according to our [manifest JSON schema](../../gateway/src/apicast/policy/manifest-schema.json).

