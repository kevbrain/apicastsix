# Making APIcast listen on HTTPS

APIcast HTTPS is controlled by `APICAST_HTTPS_*` variables defined in [the documentation](../../doc/parameters.md).

## Starting Docker

```sh
docker run \
  --env APICAST_HTTPS_PORT=8443 --publish 8443:8443 \
  --volume $(pwd)/cert:/var/run/secrets/apicast \
  --env APICAST_HTTPS_CERTIFICATE=/var/run/secrets/apicast/server.crt \
  --env APICAST_HTTPS_CERTIFICATE_KEY=/var/run/secrets/apicast/server.key \
  quay.io/3scale/apicast:master apicast \
  --dev # this flag makes APIcast start without configuration in development mode
```

1) `APICAST_HTTPS_PORT` configures APIcast to start listening on HTTPS port.
2) `--volume` mounts certificates to some path inside the container
3) `APICAST_HTTPS_CERTIFICATE` points to the public key inside the container
3) `APICAST_HTTPS_CERTIFICATE_KEY` points to the private key inside the container

## Testing

```sh
curl https://localhost:8443 -v --cacert cert/server.crt
```

> * Connected to localhost (127.0.0.1) port 8443 (#0)
> * ALPN, offering h2
> * ALPN, offering http/1.1
> * Cipher selection: ALL:!EXPORT:!EXPORT40:!EXPORT56:!aNULL:!LOW:!RC4:@STRENGTH
> * successfully set certificate verify locations:
> *   CAfile: cert/server.crt
>     CApath: /usr/local/etc/openssl/certs
> * TLSv1.2 (OUT), TLS header, Certificate Status (22):
> * TLSv1.2 (OUT), TLS handshake, Client hello (1):
> * TLSv1.2 (IN), TLS handshake, Server hello (2):
> * TLSv1.2 (IN), TLS handshake, Certificate (11):
> * TLSv1.2 (IN), TLS handshake, Server key exchange (12):
> * TLSv1.2 (IN), TLS handshake, Server finished (14):
> * TLSv1.2 (OUT), TLS handshake, Client key exchange (16):
> * TLSv1.2 (OUT), TLS change cipher, Client hello (1):
> * TLSv1.2 (OUT), TLS handshake, Finished (20):
> * TLSv1.2 (IN), TLS change cipher, Client hello (1):
> * TLSv1.2 (IN), TLS handshake, Finished (20):
> * SSL connection using TLSv1.2 / ECDHE-RSA-AES256-GCM-SHA384
> * ALPN, server accepted to use http/1.1
> * Server certificate:
> *  subject: O=Red Hat; OU=3scale; CN=localhost
> *  start date: Feb 23 07:47:00 2018 GMT
> *  expire date: Feb 21 07:47:00 2028 GMT
> *  common name: localhost (matched)
> *  issuer: O=Red Hat; OU=3scale; CN=localhost
> *  SSL certificate verify ok.
