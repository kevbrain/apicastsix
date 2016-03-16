DOCKER-GATEWAY
==============

### Description

This Dockerfile creates a [3scale](http://www.3scale.net) gateway, and configures itself according to your 3scale params.


### Running docker-gateway image

You can download a ready to use docker image from our repository:

```
docker pull quay.io/3scale/gateway
```

The 3scale gateway image requires two ENV variables:

* **THREESCALE_PROVIDER_KEY**

You can find the provider_key inside your "Account" page.

![provider_key](https://www.dropbox.com/s/6u1qae5huv602ft/Accounts_-_Show___3scale_API_Management.png?dl=1)


* **THREESCALE_ENDPOINT**

It's the full URL you use for accessing 3scale admin portal,

for example: "https://MyCompany-admin.3scale.net"


#### Docker command

```
$ docker run -d -p 80:80 -e THREESCALE_PROVIDER_KEY=ABCDFEGHIJLMNOPQRST -e THREESCALE_ENDPOINT=https://your-domain.3scale.net quay.io/3scale/gateway
```

### Auto updating

The gateway is able of checking the configuration from time to time and self update, you can enable this setting the var AUTO_UPDATE to true:

```
-e AUTO_UPDATE=true
```

By default this is disabled

NOTE: Not recommended to use in a production environment, this can have some side effects if the update runs in the middle of modifications in the 3scale UI. 
      If you want to automate this step, is better to issue a USR2 signal to the container once changes are completed in the 3scale UI. (check Signals section)


### Signals

You can send some signals to the container:

* USR1: Reloads openresty.

* USR2: Downloads 3scale configurations and updates running openresty.

Use docker kill -$SIGNAL container-name to send them. 


