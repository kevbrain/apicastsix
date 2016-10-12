# Management API

Management API is a simple API that allows updating or retrieving the configuration currently used by the gateway. The API is available on port `8090`.

Available endpoints:

- `GET /config`

 Returns the current configuration (in JSON format by default).

 ```shell
 curl -XGET http://gateway:8090/config
 ```

- `POST /config` and `PUT /config`

 Update the configuration with the JSON set in a body.

 ```shell
 curl -XPOST http://gateway:8090/config -d @example-config.json
 ```
 See [example-config.json](../examples/configuration/example-config.json) file for an example of the payload. This JSON contains the configuration of the API(s) in 3scale account, and can be downloaded from the 3scale admin portal using the URL [https://ACCOUNT-admin.3scale.net/admin/api/nginx/spec.json](https://ACCOUNT-admin.3scale.net/admin/api/nginx/spec.json) (replace `ACCOUNT` with your 3scale account name).
 The call should return something like:
 
 ```shell
 {"status":"ok","config":{"services":[...]}}
 ```

- `DELETE /config`

 Deletes the current configuration.

 ```shell
 curl -XDELETE http://gateway:8090/config
 ```
 It returns:

 ```shell
 {"status":"ok","config":null}
 ```