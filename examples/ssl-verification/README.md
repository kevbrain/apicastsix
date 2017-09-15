# SSL/TLS Verification

APIcast supports certificate verification against trusted CAs. This feature is off by default because some environments use custom CAs and would make those connections fail by default.

## Upstream verification

This validation is controller by `proxy_ssl_*` nginx directives. Everything is set up to use default OS trusted certificates. Only step needed is to add custom configuration to enable the verification:

```nginx
# apicast.d/proxy_ssl.conf
proxy_ssl_verify on;
```

## 3scale AMP verification

To enable verification for connections between APIcast and 3scale AMP you'll need to set `OPENSSL_VERIFY` environment variable. Everything is set up to use the default OS  trusted certificate chain.

```shell
docker run --env OPENSSL_VERIFY=true apicast
```