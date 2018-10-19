use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{TEST_NGINX_HTML_DIR} ||= "$Test::Nginx::Util::ServRoot/html";

run_tests();

__DATA__
=== TEST 1: Listen on HTTPS
--- env eval
(
    'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
    'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
    'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
)
--- configuration fixture=echo.json
--- test env
lua_ssl_trusted_certificate $TEST_NGINX_HTML_DIR/server.crt;
content_by_lua_block {
    local sock = ngx.socket.tcp()
    sock:settimeout(2000)

    local ok, err = sock:connect(ngx.var.server_addr, ngx.var.apicast_port)
    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end

    ngx.say("connected: ", ok)

    local sess, err = sock:sslhandshake(nil, "localhost", true)
    if not sess then
        ngx.say("failed to do SSL handshake: ", err)
        return
    end

    ngx.say("ssl handshake: ", type(sess))
}
--- response_body
connected: 1
ssl handshake: userdata
--- error_code: 200
--- no_error_log
[error]
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIBRzCB7gIJAPHi8uNGM8wDMAoGCCqGSM49BAMCMCwxFjAUBgNVBAoMDVRlc3Q6
OkFQSWNhc3QxEjAQBgNVBAMMCWxvY2FsaG9zdDAeFw0xODA2MDUwOTQ0MjRaFw0y
ODA2MDIwOTQ0MjRaMCwxFjAUBgNVBAoMDVRlc3Q6OkFQSWNhc3QxEjAQBgNVBAMM
CWxvY2FsaG9zdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABI3IZUvpJsaQbiLy
/yfthJDd/+BIaKzAbgMAimth4ePOi3a/YICwsHyq6sBxbgvMeTwxNJIHpe3td4tB
VZ5Wr10wCgYIKoZIzj0EAwIDSAAwRQIhAPRkfbxowt0H7p5xZYpwoMKanUXz9eKQ
0sGkOw+TqqGXAiAMKJRqtjnCF2LIjGygHG6BlgjM4NgIMDHteZPEr4qEmw==
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIH22v43xtXcHWJyH3BEB9N30ahrCOLripkoSWW/WujUxoAoGCCqGSM49
AwEHoUQDQgAEjchlS+kmxpBuIvL/J+2EkN3/4EhorMBuAwCKa2Hh486Ldr9ggLCw
fKrqwHFuC8x5PDE0kgel7e13i0FVnlavXQ==
-----END EC PRIVATE KEY-----



=== TEST 2: Listen on HTTPS with policy serving the certificate
--- env eval
(
    'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
    'APICAST_POLICY_LOAD_PATH' => 't/fixtures/policies',
)
--- configuration
{
  "services": [{
    "proxy": {
      "policy_chain": [
        { "name": "https", "configuration": {
            "certificate": "-----BEGIN CERTIFICATE-----\nMIIBRzCB7gIJAPHi8uNGM8wDMAoGCCqGSM49BAMCMCwxFjAUBgNVBAoMDVRlc3Q6\nOkFQSWNhc3QxEjAQBgNVBAMMCWxvY2FsaG9zdDAeFw0xODA2MDUwOTQ0MjRaFw0y\nODA2MDIwOTQ0MjRaMCwxFjAUBgNVBAoMDVRlc3Q6OkFQSWNhc3QxEjAQBgNVBAMM\nCWxvY2FsaG9zdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABI3IZUvpJsaQbiLy\n/yfthJDd/+BIaKzAbgMAimth4ePOi3a/YICwsHyq6sBxbgvMeTwxNJIHpe3td4tB\nVZ5Wr10wCgYIKoZIzj0EAwIDSAAwRQIhAPRkfbxowt0H7p5xZYpwoMKanUXz9eKQ\n0sGkOw+TqqGXAiAMKJRqtjnCF2LIjGygHG6BlgjM4NgIMDHteZPEr4qEmw==\n-----END CERTIFICATE-----",
            "key": "-----BEGIN EC PARAMETERS-----\nBggqhkjOPQMBBw==\n-----END EC PARAMETERS-----\n-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEIH22v43xtXcHWJyH3BEB9N30ahrCOLripkoSWW/WujUxoAoGCCqGSM49\nAwEHoUQDQgAEjchlS+kmxpBuIvL/J+2EkN3/4EhorMBuAwCKa2Hh486Ldr9ggLCw\nfKrqwHFuC8x5PDE0kgel7e13i0FVnlavXQ==\n-----END EC PRIVATE KEY-----" } },
        { "name": "apicast.policy.upstream",
          "configuration": { "rules": [ { "regex": "/", "url": "http://echo" } ] } }
      ]
    }
  }]
}
--- test env
lua_ssl_trusted_certificate $TEST_NGINX_HTML_DIR/server.crt;

content_by_lua_block {
    local sock = ngx.socket.tcp()
    sock:settimeout(2000)

    local ok, err = sock:connect(ngx.var.server_addr, ngx.var.apicast_port)
    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end

    ngx.say("connected: ", ok)

    local sess, err = sock:sslhandshake(nil, "localhost", true)
    if not sess then
        ngx.say("failed to do SSL handshake: ", err)
        return
    end

    ngx.say("ssl handshake: ", type(sess))
}
--- response_body
connected: 1
ssl handshake: userdata
--- error_code: 200
--- no_error_log
[error]
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIBRzCB7gIJAPHi8uNGM8wDMAoGCCqGSM49BAMCMCwxFjAUBgNVBAoMDVRlc3Q6
OkFQSWNhc3QxEjAQBgNVBAMMCWxvY2FsaG9zdDAeFw0xODA2MDUwOTQ0MjRaFw0y
ODA2MDIwOTQ0MjRaMCwxFjAUBgNVBAoMDVRlc3Q6OkFQSWNhc3QxEjAQBgNVBAMM
CWxvY2FsaG9zdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABI3IZUvpJsaQbiLy
/yfthJDd/+BIaKzAbgMAimth4ePOi3a/YICwsHyq6sBxbgvMeTwxNJIHpe3td4tB
VZ5Wr10wCgYIKoZIzj0EAwIDSAAwRQIhAPRkfbxowt0H7p5xZYpwoMKanUXz9eKQ
0sGkOw+TqqGXAiAMKJRqtjnCF2LIjGygHG6BlgjM4NgIMDHteZPEr4qEmw==
-----END CERTIFICATE-----

=== TEST 3: Listen on HTTPS with path-based routing enabled
Regression test. APIcast was crashing because path-based routing needs the http
method and the path. However, those are not available when trying to find the
service in the ssl_certificate phase.
This test checks that APIcast falls back to finding the service by host.
--- env eval
(
    'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
    'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
    'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
    'APICAST_PATH_ROUTING' => "true",
)
--- configuration fixture=echo.json
--- test env
lua_ssl_trusted_certificate $TEST_NGINX_HTML_DIR/server.crt;
content_by_lua_block {
    local sock = ngx.socket.tcp()
    sock:settimeout(2000)

    local ok, err = sock:connect(ngx.var.server_addr, ngx.var.apicast_port)
    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end

    ngx.say("connected: ", ok)

    local sess, err = sock:sslhandshake(nil, "localhost", true)
    if not sess then
        ngx.say("failed to do SSL handshake: ", err)
        return
    end

    ngx.say("ssl handshake: ", type(sess))
}
--- response_body
connected: 1
ssl handshake: userdata
--- error_code: 200
--- grep_error_log eval: qr/Falling back to routing by host/
--- grep_error_log_out
Falling back to routing by host
--- no_error_log
[error]
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIBRzCB7gIJAPHi8uNGM8wDMAoGCCqGSM49BAMCMCwxFjAUBgNVBAoMDVRlc3Q6
OkFQSWNhc3QxEjAQBgNVBAMMCWxvY2FsaG9zdDAeFw0xODA2MDUwOTQ0MjRaFw0y
ODA2MDIwOTQ0MjRaMCwxFjAUBgNVBAoMDVRlc3Q6OkFQSWNhc3QxEjAQBgNVBAMM
CWxvY2FsaG9zdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABI3IZUvpJsaQbiLy
/yfthJDd/+BIaKzAbgMAimth4ePOi3a/YICwsHyq6sBxbgvMeTwxNJIHpe3td4tB
VZ5Wr10wCgYIKoZIzj0EAwIDSAAwRQIhAPRkfbxowt0H7p5xZYpwoMKanUXz9eKQ
0sGkOw+TqqGXAiAMKJRqtjnCF2LIjGygHG6BlgjM4NgIMDHteZPEr4qEmw==
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIH22v43xtXcHWJyH3BEB9N30ahrCOLripkoSWW/WujUxoAoGCCqGSM49
AwEHoUQDQgAEjchlS+kmxpBuIvL/J+2EkN3/4EhorMBuAwCKa2Hh486Ldr9ggLCw
fKrqwHFuC8x5PDE0kgel7e13i0FVnlavXQ==
-----END EC PRIVATE KEY-----
