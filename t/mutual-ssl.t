use lib 't';
use Test::APIcast::Blackbox 'no_plan';

env_to_apicast(
    'APICAST_PROXY_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/client.crt",
    'APICAST_PROXY_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/client.key",
    'APICAST_PROXY_HTTPS_PASSWORD_FILE' => "$Test::Nginx::Util::ServRoot/html/passwords.file",
    'APICAST_PROXY_HTTPS_SESSION_REUSE' => 'on',
);

run_tests();

__DATA__

=== TEST 1: Mutual SSL with password file
--- ssl random_port
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "https://test:$TEST_NGINX_RANDOM_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream env
  listen $TEST_NGINX_RANDOM_PORT ssl;

  ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
  ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

  ssl_client_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
  ssl_verify_client on;

  location / {
     echo 'ssl_client_s_dn: $ssl_client_s_dn';
     echo 'ssl_client_i_dn: $ssl_client_i_dn';
  }
--- request
GET /?user_key=uk
--- response_body
ssl_client_s_dn: O=Internet Widgits Pty Ltd,ST=Some-State,C=AU
ssl_client_i_dn: O=Internet Widgits Pty Ltd,ST=Some-State,C=AU
--- error_code: 200
--- no_error_log
[error]
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIB0DCCAXegAwIBAgIJAISY+WDXX2w5MAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTYxMjIzMDg1MDExWhcNMjYxMjIxMDg1MDExWjBFMQsw
CQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhkmo
6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1cbx0wVEzbYK5wRb7U
iWhvvvYDltIzsD75vqNQME4wHQYDVR0OBBYEFOBBS7ZF8Km2wGuLNoXFAcj0Tz1D
MB8GA1UdIwQYMBaAFOBBS7ZF8Km2wGuLNoXFAcj0Tz1DMAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDRwAwRAIgZ54vooA5Eb91XmhsIBbp12u7cg1qYXNuSh8zih2g
QWUCIGTHhoBXUzsEbVh302fg7bfRKPCi/mcPfpFICwrmoooh
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIFCV3VwLEFKz9+yTR5vzonmLPYO/fUvZiMVU1Hb11nN8oAoGCCqGSM49
AwEHoUQDQgAEhkmo6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1c
bx0wVEzbYK5wRb7UiWhvvvYDltIzsD75vg==
-----END EC PRIVATE KEY-----
>>> client.crt
-----BEGIN CERTIFICATE-----
MIICATCCAWoCCQCoHzh0BKl/SzANBgkqhkiG9w0BAQsFADBFMQswCQYDVQQGEwJB
VTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJuZXQgV2lkZ2l0
cyBQdHkgTHRkMB4XDTE4MTAwNzIxMjIwNFoXDTE4MTEwNjIxMjIwNFowRTELMAkG
A1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoMGEludGVybmV0
IFdpZGdpdHMgUHR5IEx0ZDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEArV2H
7BjV1lmnLDhr64H7Gd5Ui3GtHgmPF4iMuQq82VWNY/CZV+ZHAWNcemszqTmsoFOA
hYuyax8LnkygeNPyURptunfTTRU9NMcSdFSQRUmrrr5deo6jW2wxqhcFG8yEVKRm
88lu7NIiu33wpao+pt6PeOTEatHFi3YfvVHq0oECAwEAATANBgkqhkiG9w0BAQsF
AAOBgQDHGkUXUMbugBe81LsvfHeqOCxyGZKyTlgjIj2lFp30tBz6V7sn+jMfwXj4
GhZVbFEGydm0JWjW75qZUMfn1bL91rpMgP0bi3VyTLDZsd2aElilHPrY6mURTAIJ
BXfZnEfbCHituhhhsiPwmTmX/1Eot8oJK2CcZyVsmxlhCzMogQ==
-----END CERTIFICATE-----
>>> client.key
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,53539C1EC3FAFCA8

OOnYq1xGINyVT8IKN/soLSPsXIf4fzHPiXe44cVw3NY0G+WG5BmEoHTCNufwRxer
iCaOBa5vAkNmpAxLp2zHUHagEiL0YiWPFKYtE8r1hVxeMX80Ki7OIvX/4ts6fnfs
YN5zjy2GEas4Hoz8XHafHwroC+GknqJi8qbf1PeG/liRCdZAJsF98OjH2CUqhC1y
0dxG8HujUXmheaTLlWqTO175AKvIvarBO9FuyVZVe4qiTbciT0KwWmddM0XCnLOB
vSfExf1yD4klblx14DrvqhR1OO/vGVnecCQZXz0VLBNCBST1aGB50gXJjPiIFx9L
cEEOA0QEV8gN/aQ9J0+Pd4aYbvVXu9gaoGkJUTFHg5W/iUbH3luOe34FMdRzwR0i
bYq9fQ2074c3zYOcI4WzmShVv6qzFDSz2KiStqGriS63s/5FenQgWEjHK4ImmQ81
G0lFs9pnbD8sGjYkJSX5um3z+9OoW0KZnFKrCpILDnpexmkitwgDr6KWU4YTZ05p
FWBqCd6pjxuNbdg3sJsofjWPwbPU954ksloajVXRrHHDNjnyB80ZCdtavLl2ZFO/
p8KYIrMBD1zNZtR1p2+W0mrGk9cE1fjOhwEznxsPw8FvSdC8KflYtjiGcihcHxS5
Nq/j/ftw3ptIenOsGw7pCE5FJHFdxGefkJCSx03/OIzuoVn5mMXDkvt7jmE2rOuJ
DNuuQcnqN7YovLuLuwI/6DBxhd5nUWCBIDNo3sEUPXZY7Q0zmGHUPrBNFnKEXkKi
aQ6jARTSQ8kxNlhq0qwVE0oq9eFfZLm6ANpwr6U/+dQ=
-----END RSA PRIVATE KEY-----
>>> passwords.file
password