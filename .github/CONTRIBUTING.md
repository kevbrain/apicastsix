# Issue Reporting

To fix the issue, we need to reproduce it first, so we can write a test case to prevent it from happening in the future. That means can't fix issues, we can't reproduce. Contributing failing test case is also very appreciated.

For us to sucessfuly reproduce issue we need either

* failing test case using Test::Nginx (see folder [t/](../t)) 
* or minimal configuration and curl commands describing the http requests as steps to reproduce it.

## Minimal configuration

The whole configuration can be pretty big, but most of it can be ignored as will use some defaults. The minimal reasonable configuration is described as JSON schema in [schema.json](../schema.json). Examples of those configurations are in [examples/configuration/](../examples/configuration). You can download your configuration from the Admin Portal: `https://ACCOUNT-admin.3scale.net/admin/api/nginx/spec.json`. Then remove everything that does not concern your use case and remove all private information. Removing the `services.proxy.backend` (like in [multiservice.json example](../examples/configuration/multiservice.json)) entry will make it to to authorize every request for sake of testing.

## Running with custom configuration

When you download the configuration from your portal and customize it, you need to run the API gateway with that configuration. That is done via environment variable and mounting a file.

You'll need to run the API gateway locally, either in docker or by compiling Openresty yourself.

Run the docker container with custom configuration:

```shell
docker run --rm --publish-all --env THREESCALE_CONFIG_FILE=/config.json --volume $(pwd)/examples/configuration/multiservice.json:/config.json --name test-gateway-config quay.io/3scale/apicast:v2
```

And send to that docker image against that configuration:

```shell
curl -v "http://$(docker port test-gateway-config 8080)/?user_key=value" -H 'Host: monitoring'
```

Locally you can start openresty by:

```shell
THREESCALE_CONFIG_FILE=examples/configuration/multiservice.json nginx -p . -c conf/nginx.conf -g 'daemon off;'
```

And send a request to it:

```shell
curl -v "http://127.0.0.1:8080/?user_key=value" -H "Host: your-service"
```

It is important to send proper Host header, as that is used to route between different services. It has to match `hosts` key in the configuration.

# Development

TBD