# Management API

Management API is a simple API that allows updating or getting the configuration currently used by the gateway. The API is available on port `8090`.

Available endpoints:

- `GET /config`
 Returns the current configuration (in JSON format by default).

 ```
 curl -XGET http://gateway:8090/config
 ```

- `POST /config` and `PUT /config`
 Update the configuration with the JSON set in a body.

 ```
 curl -XPOST http://gateway:8090/config -d @example-config.json
 ```
 See the `example-config.json` file [examples/configuration](examples/configuration).
 It should return something like:
 
 ```
 {"status":"ok","config":{"services":[...]}}
 ```

- `DELETE /config`
 Deletes the current configuration.

 ```
 curl -XDELETE http://gateway:8090/config
 ```
 It returns:

 ```
 {"status":"ok","config":null}
 ```