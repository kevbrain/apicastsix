# TLS Validation policy

This policy can validate TLS Client Certificate against a whitelist.

Whitelist expects PEM formatted CA or Client certificates.
It is not necessary to have the full certificate chain, just partial matches are allowed.
For example you can add to the whitelist just leaf client certificates without the whole bundle with a CA certificate.
