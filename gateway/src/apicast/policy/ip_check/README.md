# IP Check policy

- [**Description**](#description)
- [**Examples**](#examples)


## Description

This policy allows to deny requests based on a blacklist or a whitelist of IPs.

The policy accepts a "check_type" ("blacklist" or "whitelist") and a list of
IPs. When the `check_type` is "blacklist", the policy denies all the requests
that have an IP included in the list provided. When the `check_type` is
"whitelist", the policy denies the request only if the IP is not included in the
list provided.

In the configuration, both single IPs (like 172.18.0.1) and CIDR ranges (like
172.18.0.0/16) can be used.

The message error that is returned when the request is denied can be configured
with the `error_msg` field.

The policy allows to specify how to retrieve the client IP that will be checked
against the list of blacklisted or whitelisted IPs. This is configured with the
`client_ip_sources` field. By default, the last caller IP will be used, but the
policy can be configured to check the "X-Forwarded-For" or the "X-Real-IP"
headers too.


## Examples

- Blacklist an IP and a range:
```json
{
  "name": "ip_check",
  "configuration": {
    "ips": [ "3.4.5.6", "1.2.3.0/4" ],
    "check_type": "blacklist"
  }
}
```

- Whitelist an IP and a range:
```json
{
  "name": "ip_check",
  "configuration": {
    "ips": [ "3.4.5.6", "1.2.3.0/4" ],
    "check_type": "whitelist"
  }
}
```

- Blacklist some IPs and customize the error message:
```json
{
  "name": "ip_check",
  "configuration": {
    "ips": [ "3.4.5.6", "1.2.3.0/4" ],
    "check_type": "blacklist",
    "error_msg": "A custom error message"
  }
}
```

- Specify where to get the client IP from:
```json
{
  "name": "ip_check",
  "configuration": {
    "ips": [ "3.4.5.6", "1.2.3.0/4" ],
    "check_type": "blacklist",
    "client_ip_sources": ["X-Forwarded-For"]
  }
}
```

- Specify several sources to get the IP from. They are tried in order:
```json
{
  "name": "ip_check",
  "configuration": {
    "ips": [ "3.4.5.6", "1.2.3.0/4" ],
    "check_type": "blacklist",
    "client_ip_sources": ["X-Forwarded-For", "X-Real-IP", "last_caller"]
  }
}
```

To know more about the details of what is exactly supported please check the
[policy config schema](apicast-policy.json).
