# Configuration from JSON

You can give APIcast configuration from JSON file. Either via `THREESCALE_CONFIG_FILE` environment variable or `-c` on the command line.

## Docker

```shell
docker run --publish 8080:8080 --detach --rm --volume $(pwd)/echo.json:/echo.json --env THREESCALE_CONFIG_FILE=/echo.json quay.io/3scale/apicast:master
curl "localhost:8080?user_key=foo" -v
```

Prints:

```
* Rebuilt URL to: localhost:8080/?user_key=foo
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 8080 (#0)
> GET /?user_key=foo HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.51.0
> Accept: */*
>
< HTTP/1.1 200 OK
< Server: openresty/1.11.2.2
< Date: Thu, 02 Mar 2017 17:21:09 GMT
< Content-Type: text/plain
< Transfer-Encoding: chunked
< Connection: keep-alive
< X-3scale-matched-rules: /
< X-3scale-credentials: user_key=foo
< X-3scale-usage: usage%5Bhits%5D=1
< X-3scale-hostname: ad636c304851
<
GET /?user_key=foo HTTP/1.1
X-Real-IP: 172.17.0.1
Host: echo
User-Agent: curl/7.51.0
Accept: */*



* Curl_http_done: called premature == 0
* Connection #0 to host localhost left intact
```

Which is the custom `echo.json` configuration that prints the request back.
