Running APIcast with OAuth 
==========================

The API Gateway has a dependency on Redis when adding OAuth support. 

In this case, `docker-compose` has to be run in order to start up all of the required components. 

The command to do so is:

```shell
docker-compose up -d
```

from the directory containing the `docker-compose.yml` file (in this case `/examples/oauth2`).

The `-d` flag starts the containers up in detached mode, if you want to see the output when starting the containers, you should omit this. 

In order for the command to run successfully, you will also need a `.env` file with the following content (substituting the THREESCALE_PORTAL_ENDPOINT value with your own):

```
# URI to fetch gateway configuration from. Expected format is: https?://[password@]hostname
THREESCALE_PORTAL_ENDPOINT=https://access_token@example-admin.3scale.net

# Redis host. Used to store access tokens.
REDIS_HOST=redis
```

The docker compose file spins up 4 services:

1. APIcast
2. Redis 
3. A very simple Authorization Server (auth-server) written in Ruby
4. A sample Client to request an Authorization code and exchange that for an Access Token

3scale setup
------------

To get this working with a 3scale instance the following conditions should be met:

1. Self-managed deployment type and OAuth authentication method should be selected
2. *OAuth Authorization Endpoint* on the Integration page needs to be configured, e.g. if you're running the auth-server app on localhost this would be `http://localhost:3000/auth/login`
3. Set the *Public Base URL* in the Production section of the Integration page to the gateway host e.g `http://localhost:8080`
4. An application created in 3scale configured with its **Redirect URL** to point to the `client.rb` instance, e.g `http://localhost:3001/callback` 

Once you have APIcast configured to point to your local OAuth testing instance (Gateway + Auth Server), and you have run `docker-compose up` to start all of the required components, you can navigate to your client instance (in this case `client.rb` running on `localhost:3001`) to request an access token. 

client.rb
---------

A very simple Sinatra app acting as a Client, running on `http://localhost:3001`.

The app will display a page where you can enter a `client_id`, `redirect_uri` and `scope` to request an authorization code. 

The Authorization URL targeted will be the `/authorize` endpoint on your API Gateway instance, e.g `http://localhost:8080/authorize` 
The Access Token URL targeted will be the `/oauth/token` endpoint on your API Gateway instance. e.g `http://localhost:8080/oauth/token`

Both these values are built in to the client, however, the Gateway URI can be overwritten by adding a `.env` file under the `client` directory and specifying the gateway URI in the `GATEWAY` environment variable (in format `<scheme>://<host>:<port>`), otherwise this will default to `http://localhost:8080`

Once an authorization code is returned back to the app, you can exchange that for an access token by additionally providing a client secret.

### Requesting an authorization code

You can then click **Authorize** under "Step 1: Request Authorization Code" to initiate the access token request process. 

### Exchanging authorization code for an access token

When the authorization code is returned, you can enter in your `client_id` and `client_secret` under "Step 2: Exchange Authorization Code for Access Token" and click **Get Token** to request an access token. 

auth-server.rb
--------------

A very simple Sinatra app acting as an Authorization Server, running on `http://localhost:3000`. 

The app will display a log in page (`/auth/login`) which will accept any values for username and password.
Once logged in, a consent page will be displayed to accept or deny the request. 

The authorization server will callback APIcast (running on `http://localhost:8080`) to issue an authorization code on request acceptance and the `redirect_uri` directly on denial. 

Once the Authorization Code is sent to the redirect URL (client callback endpoint in this case) we exchange this for an access token as per the instructions above under "Exchanging authorization code for an access token."

The `auth-server.rb` code for running this example using `docker-compose` locally assumes that the Gateway host is running on `http://localhost:8080`. You can always override this by adding a `.env` file in the `auth-server` directory and referencing this within your `docker-compose.yml` file, same as for `client.rb`.
