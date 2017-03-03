# Running APIcast with RH-SSO for OIDC


## Client Registration

In order to authenticate clients in RH SSO and correctly track usage in 3scale, client credentials need to be synchronised between the 2 systems. Typically this functionality would fall outside the realm of the Gateway, but we will show how you can implement this within the Gateway to provide a self contained environment.

The following instructions are only required if you want to manage client registrations from APIcast. Otherwise you can skip this whole section.

### Pre-requisites

- Redis server needs to be running
- The following dependencies need to be installed via yum
    - expat-devel: `sudo yum install expat-devel`
    - C compiler and development tools: `sudo yum group install "Development Tools"`
- The following lua libraries should be installed using luarocks: 
    - luaexpat: `sudo luarocks install luaexpat --tree=/usr/local/openresty/luajit`
    - luaxpath: `sudo luarocks install luaxpath --tree=/usr/local/openresty/luajit`
    - cjson: `sudo luarocks install lua-cjson --tree=/usr/local/openresty/luajit`
- And a symbolic link created: so openresty can find them
    `ln -s /usr/local/openresty/luajit/lib64/lua/5.1/* /usr/local/openresty/luajit/lib/lua/5.1/` 

### Set up

We will use the same approach as in the Custom Configuration example to add an additional server block to handle the client registration in RH SSO. In this case, clients will be created in 3scale first and imported into RH SSO. 

The way to do this is in docker would be by mounting a volume inside `sites.d` folder in the container.

Additionally we need to add some additional code to deal with client registration webhooks. This is included in `webhook-handler.lua`. Before you mount this file into the docker container, you will need to fill in the "Initial Access Token" value. Simply find `CHANGE_ME_INITIAL_ACCESS_TOKEN` in `webhook_handler.lua` and replace with the initial access token value for your realm. You can read more about this initial access token in the [RH SSO documentation](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.0/html/securing_applications_and_services_guide/client_registration#initial_access_token).

Altogether these 2 files would be mounted as follows: 

```shell
docker run --publish 8080:8080 --volume $(pwd)/rh-sso.conf:/opt/app/sites.d/rh-sso.conf --volume $(pwd)/client-registrations:/opt/app/src/client-registrations --env RHSSO_ENDPOINT=https://{rh-sso-host}:{port}/auth/realms/{your-realm} --env THREESCALE_PORTAL_ENDPOINT=http://portal.example.com quay.io/3scale/apicast:master
```

If you're running natively, you can just add these files directly into `apicast/sites.d` and `apicast/src` respectively.

