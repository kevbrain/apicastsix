# Customizing APIcast server block

Like adding SSL or anything in the nginx [server](http://nginx.org/en/docs/http/ngx_http_core_module.html#server) block.

## Adding SSL

APIcast will read all `.conf` files in the `apicast.d` folder inside its prefix as part of the APIcast server configuration.

## Starting Docker

```sh
docker run -it -v $(pwd)/apicast.d:/opt/app-root/src/apicast.d:ro -v $(pwd)/cert:/opt/app-root/src/conf/cert:ro --env THREESCALE_PORTAL_ENDPOINT=https://git.io/vXHTA --publish 8443:8443 quay.io/3scale/apicast:master
```

Mounts `cert` and `apicast.d` folder to the correct place and exposes port 8443 that the `ssl.conf` defines.

## Testing

```sh
curl -k -v https://localhost:8443
```

> *   Trying 127.0.0.1...
> *   Connected to localhost (127.0.0.1) port 8443 (#0)
> *   TLS 1.2 connection using TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
> *   Server certificate: Internet Widgits Pty Ltd

## Note

The `THREESCALE_PORTAL_ENDPOINT` variable points to configuration that uses local backend, so it can be used without any account.
