
# **WARNING**: this is documentation for development branch, that might not be working at any point. To see stable version go to [`master` branch](https://github.com/3scale/docker-gateway/tree/master).


# Gateway

`v2` branch is **not stable** yet and **not recommended for production** use.

## Description

This Dockerfile creates a [3scale](http://www.3scale.net) gateway, and configures itself according to your 3scale params.

## OpenShift

To run the gateway on OpenShift, just use template and create a Secret to point to your 3scale Admin Portal.

```shell
oc secret new-basicauth threescale-portal-endpoint-secret --password=https://provider-key@account-admin.3scale.net
oc new-app -f https://raw.githubusercontent.com/3scale/docker-gateway/v2/3scale-gateway-openshift-template.yml
```

## Docker

You can download a ready to use docker image from our repository:

```
docker pull quay.io/3scale/gateway:v2
```

The 3scale gateway image requires two ENV variables:

* **THREESCALE_PORTAL_ENDPOINT**

URI that includes your password and portal endpoint in following format: `schema://access-token@domain`.
Example: https://provider-key@test-admin.3scale.net

* **THREESCALE_CONFIG_FILE**

Path to saved JSON file with configuration for the gateway. Has to be injected to the docker image as read only volume.

#### Docker command

```
$ docker run -d -p 8080:8080 -e THREESCALE_PORTAL_ENDPOINT=https://access-token@test-admin.3scale.net quay.io/3scale/gateway:v2
```

### Auto updating (not working yet)

The gateway is able of checking the configuration from time to time and self update, you can enable this by adjusting the AUTO_UPDATE_INTERVAL (seconds) to some value greater than 60:

```
-e AUTO_UPDATE_INTERVAL=300
```

This variable is set to 0 by default.

### Signals

Signals are the same as normal nginx.

Use docker kill -s $SIGNAL container-name to send them.

# Development & Testing

## OSX

To install openresty and luarocks, just use Homebrew:

```shell
brew install apitools/openresty/luarocks
```

To run tests, you'll also need Test::Nginx from cpan:

```shell
cpan Test::Nginx
```
