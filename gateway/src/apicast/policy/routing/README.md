# Routing policy

- [**Description**](#description)
- [**Rule that uses the request path**](#rule-that-uses-the-request-path)
- [**Rule that uses a header**](#rule-that-uses-a-header)
- [**Rule that uses a query argument**](#rule-that-uses-a-query-argument)
- [**Rule that uses a jwt claim**](#rule-that-uses-a-jwt-claim)
- [**Rule with several operations**](#rule-with-several-operations)
- [**Combining rules**](#combining-rules)
- [**Supported operations**](#supported-operations)
- [**Liquid templating**](#liquid-templating)

## Description

This policy allows to modify the upstream (scheme, host, and port) of a request
based on:

- The request path
- A header
- A query argument
- A jwt claim

## Rule that uses the request path

This is a configuration that routes to `http://example.com` when the path is
`/accounts`:

```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "path",
                "op": "==",
                "value": "/accounts"
              }
            ]
          }
        }
      ]
    }
  }
```

## Rule that uses a header

This is a configuration that routes to `http://example.com` when the value of
the header `Test-Header` is `123`:

```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "header",
                "header_name": "Test-Header",
                "op": "==",
                "value": "123"
              }
            ]
          }
        }
      ]
    }
  }
```

## Rule that uses a query argument

This is a configuration that routes to `http://example.com` when the value of
the query argument `test_query_arg` is `123`:

```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "query_arg",
                "query_arg_name": "test_query_arg",
                "op": "==",
                "value": "123"
              }
            ]
          }
        }
      ]
    }
  }
```

## Rule that uses a jwt claim

In order to be able to route based on the value of a jwt claim, there needs to
be a policy in the chain that validates the jwt and stores it in the context
that the policies share.

This is a configuration that routes to `http://example.com` when the value of
the jwt claim `test_claim` is `123`:

```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "jwt_claim",
                "jwt_claim_name": "test_claim",
                "op": "==",
                "value": "123"
              }
            ]
          }
        }
      ]
    }
  }
```

## Rule with several operations

Rules can have several operations and route to the given upstream only when all
of them evaluate to true (using the 'and' `combine_op`), or when at least one of
them evaluates to true (using the 'or' `combine_op`). The default value of
`combine_op` is 'and'.

This is a configuration that routes to `http://example.com` when the path of the
request is `/accounts` and when the value of the header `Test-Header` is `123`:

```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "combine_op": "and",
            "operations": [
              {
                "thing_to_match": "path",
                "op": "==",
                "value": "/accounts"
              },
              {
                "thing_to_match": "header",
                "header_name": "Test-Header",
                "op": "==",
                "value": "123"
              }
            ]
          }
        }
      ]
    }
  }
```

This is a configuration that routes to `http://example.com` when the path of the
request is `/accounts` or when the value of the header `Test-Header` is `123`:

```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "combine_op": "or",
            "operations": [
              {
                "thing_to_match": "path",
                "op": "==",
                "value": "/accounts"
              },
              {
                "thing_to_match": "header",
                "header_name": "Test-Header",
                "op": "==",
                "value": "123"
              }
            ]
          }
        }
      ]
    }
  }
```

## Combining rules

Rules can be combined. When there are several of them, the upstream selected is
the one of the first rule that evaluates to true.

This is a configuration with several rules:
```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://some_upstream.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "path",
                "op": "==",
                "value": "/accounts"
              }
            ]
          }
        },
        {
          "url": "http://another_upstream.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "path",
                "op": "==",
                "value": "/users"
              }
            ]
          }
        }
      ]
    }
  }
```

## Supported operations

The supported operations are `==`, `!=`, and `matches`. The latter matches a
string with a regular expression and it is implemented using
[ngx.re.match](https://github.com/openresty/lua-nginx-module#ngxrematch)

This is a configuration that uses `!=`. It routes to `http://example.com` when
the path is not `/accounts`:
```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "path",
                "op": "!=",
                "value": "/accounts"
              }
            ]
          }
        }
      ]
    }
  }
```

## Liquid templating

It is possible to use liquid templating for the values of the configuration.
This allows to define rules with dynamic values. Suppose that a policy in the
chain stores the key `my_var` in the context. As an example, this is a
configuration that uses that value to route the request:
```json
  {
    "name": "routing",
    "version": "builtin",
    "configuration": {
      "rules": [
        {
          "url": "http://example.com",
          "condition": {
            "operations": [
              {
                "thing_to_match": "header",
                "header_name": "Test-Header",
                "op": "==",
                "value": "{{ my_var }}",
                "value_type": "liquid"
              }
            ]
          }
        }
      ]
    }
  }
```
