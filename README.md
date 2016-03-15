DOCKER-GATEWAY
==============

### Description

This Dockerfile creates a [3scale](http://www.3scale.net) gateway, and configures itself according to your 3scale params.


### Running docker-gateway image

The 3scale gateway image requires to ENV variables:

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
