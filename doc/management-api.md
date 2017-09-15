# Management API

Management API is a simple API that allows updating or retrieving the configuration currently used by the gateway. The API is available on port `8090`.

This is mean to be used for **debugging purposes only**. Offers no authentication or synchronization between several instances.

It can be exposed via `APICAST_MANAGEMENT_API` environment variable with following options:

* **debug**: full API with access to everything
* **status**: just the `/status` endpoints
* **disabled**: completely disabled

The default value is **status**.

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
 See [example-config.json](../examples/configuration/example-config.json) file for an example of the payload. This JSON contains the configuration of the API(s) in 3scale account, and can be downloaded from the 3scale admin portal using the URL `https://ACCOUNT-admin.3scale.net/admin/api/nginx/spec.json`] (replace `ACCOUNT` with your 3scale account name).
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
- `POST /boot`
  Run the initialization process. Try to download new configuration.

- `GET /dns/cache`
  Returns DNS cache like:

  ```json

  {"127.0.0.1.xip.io":
     {"expires_in":139.0790002346,"value":{"1":{"address":"127.0.0.1","section":1,"type":1,"class":1,"name":"127.0.0.1.xip.io","ttl":250},"name":"127.0.0.1.xip.io","ttl":250}}
  }
  ```
  
- `GET /status/ready`
  
  Returns one of following responses:
  
  ```json
  { "status": "error", "error": "not configured", "success": false }
  ```
  
  ```json
  { "status": "warning", "warning": "no services", "success": true }
  ```
  
  ```json
  { "status": "ready", "success": true }
  ```

- `GET /status/live`
  Returns:
  ```json
  { "status": "live", "success": true }
  ```
