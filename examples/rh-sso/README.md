# Running APIcast with RH-SSO and OIDC for API Authentication

This example shows you how to use Red Hat Single Sign-On to verify the identity of an [End-User](https://openid.net/specs/openid-connect-core-1_0.html#Terminology) and issue access tokens for use by clients wishing to access the End-User resources. 3scale will add an API Management layer, which includes access control, rate-limiting policies, and also a self-service model of registering the client applications for consuming the API.

## Pre-requisites

- 3scale account - You can sign up for a Free Trial [here](https://www.3scale.net/signup/)
- Red Hat SSO instance - [Installation](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.0/html-single/server_installation_and_configuration_guide/) and [Configuration](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.0/html/getting_started_guide/) instructions
- API - You can use the 3scale [echo API](https://echo-api.3scale.net:443)
- Client Application to consume the API - You can use a client such as [Postman](https://www.getpostman.com/)
- APIcast instance

## Red Hat Single Sign-On Configuration for APIcast

1. [Create a new realm](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.0/html/getting_started_guide/create_a_realm_and_user#create-realm) (different from Master)
2. Set up Tokens Policies (Realm Settings > Tokens) - e.g to configure access token ttl
3. Set up [Initial Access Tokens](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.0/html/securing_applications_and_services_guide/client_registration). This is necessary to synchronise client registrations between 3scale and Red Hat Single Sign-On.
    - Define Expiration - This will determine how long the access token used to register clients from APIcas will be valid for, so make sure to choose a long lived value unless you want to be changing this token often.
    - Define Count - This will determine how many clients can be registered using this access token, make sure to choose a large value unless you want to be changing this token often.
4. [Create some test End-Users](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.0/html/getting_started_guide/create_a_realm_and_user#create-new-user)

## Client Registration in APIcast (Optional)

In order to authenticate clients in RH SSO and correctly track usage in 3scale, client credentials need to be synchronised between the 2 systems. Typically this functionality would fall outside the realm of the Gateway, but we will show how you can implement this within the Gateway to provide a self contained environment.

The following instructions are only required if you want to manage client registrations from APIcast. Otherwise you can skip this whole section, however you will need to find some other mechanism to synchronise client registrations between 3scale and RH SSO e.g you can use the same webhook mechanism, but hosted outside APIcast.

### Pre-requisites

- Redis server needs to be running

### APIcast Set up

APIcast should be installed as usual with the following additional dependencies:

- The following dependencies need to be installed via yum
    - expat-devel: `sudo yum install expat-devel`
    - C compiler and development tools: `sudo yum group install "Development Tools"`
- The following lua libraries should be installed using luarocks: 
    - luaexpat: `sudo luarocks install luaexpat --tree={INSTALL_LOCATION}`. If installing on Mac, you will need to pass the EXPAT_DIR to the command, e.g `sudo luarocks install luaexpat --tree=/usr/local/openresty/luajit EXPAT_DIR=/usr/local/opt/expat`
    - luaxpath: `sudo luarocks install luaxpath --tree={INSTALL_LOCATION}`

Otherwise, please follow the instructions on the [3scale support site](https://support.3scale.net) based on your chosen [deployment option](https://support.3scale.net/docs/deployment-options/apicast-overview).

When it comes to running APIcast, we will use the same approach as in the [Custom Configuration](../custom-config) example to add an additional server block to handle the client registration in RH SSO. In this case, clients will be created in 3scale first and imported into RH SSO, e.g the way to do this is in docker would be by mounting a volume inside `sites.d` folder in the container.

Additionally we need to add some additional code to deal with client registration webhooks. This is included in `webhook-handler.lua`. Before you use this file, you will need to fill in the "Initial Access Token" value. Simply find `CHANGE_ME_INITIAL_ACCESS_TOKEN` in `webhook_handler.lua` and replace with the initial access token value for your realm. You can read more about this initial access token in the [RH SSO documentation](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.0/html/securing_applications_and_services_guide/client_registration#initial_access_token).

Altogether these 2 files would be included into APIcast as follows, e.g for docker 

```shell
docker run --publish 8080:8080 --volume $(pwd)/rh-sso.conf:/opt/app/sites.d/rh-sso.conf --volume $(pwd)/client-registrations:/opt/app/src/client-registrations --env RHSSO_ENDPOINT=https://{rh-sso-host}:{port}/auth/realms/{your-realm} --env REDIS_HOST={redis-host} --env THREESCALE_PORTAL_ENDPOINT=http://portal.example.com quay.io/3scale/apicast:master
```

If you're running natively, you can just add these files directly into `apicast/sites.d` and `apicast/src` respectively.

### 3scale Configuration

#### Webhooks
In order to register applications created in 3scale as clients in RH SSO, you need to enable and [configure webhooks](https://support.3scale.net/docs/api-bizops/webhooks) on 3scale.

1. Enter in the APIcast url followed by the `/webhooks` path. 
2. Turn Webhooks "ON."
3. Select the following Webhooks under Settings:
    - Applications > Create
    - Applications > Update
4. _Enable "Dashboard actions fire web hooks" if you want to create applications in 3scale through admin portal._

#### Create an Application/Client

Once the webhooks are configured, you will want to create an application in 3scale to test the flow. To do this through the admin portal:

1. Navigate to a Developer account you have previously created
2. Click on Applications > Create Application.
3. Select an Application Plan under the API service you have configured for RH-SSO and OpenId Connect 
4. Enter name and description and click on "Create Application"

This will generate a set of credentials for your new application. You will then need to add the redirect url for your client. For Postman, this will be: `https://www.getpostman.com/oauth2/callback` 

At the same time, in the background, 3scale sends a webhook to APIcast, which in turn makes a request to Red Hat Single Sign-On to create a Client with the same credentials. 

## APIcast setup

To get this working with a 3scale instance the following conditions should be met:

1. Self-managed deployment type and OAuth authentication method should be selected
2. *OAuth Authorization Endpoint* should be left blank as this is already defined by the RHSSO settings.
3. Set the *Public Base URL* in the Production section of the Integration page to the gateway host e.g `http://localhost:8080`
4. An application created in 3scale configured with its **Redirect URL** to point to Postman (if that's what you're using as your client), e.g `https://www.getpostman.com/oauth2/callback` 

Once you have Integrated your API as above (and you're not using APIcast for client registrations) you can run APIcast with RH-SSO and OpenId Connect support as follows, e.g if running APIcast self-managed

`RHSSO_ENDPOINT=https://{your-rh-sso-host}:{port}/auth/realms/{your-realm} THREESCALE_PORTAL_ENDPOINT=https://{3scale-access_token}@{3scale-domain}-admin.3scale.net bin/apicast`

## Testing the Integration

Once you have APIcast and RHSSO configured and up and running you can create a new request in Postman:

1. Under "Authorization", select "OAuth 2.0" 
2. Click "Get New Access Token" and fill in the following details: 
    1. Auth URL: 
    2. Access Token URL:
    3. Client ID
    4. Client Secret
    5. Grant Type: "Authorization Code"
to request an access token. 
3. You can now use the newly created access token to make a request to your API. 


