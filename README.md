
# **WARNING**: this is documentation for development branch, that might not be working at any point. To see stable version go to [`master` branch](https://github.com/3scale/docker-gateway/tree/master).


Gateway
=======

### Description

This Dockerfile creates a [3scale](http://www.3scale.net) gateway, and configures itself according to your 3scale params.


### Running docker-gateway image

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

