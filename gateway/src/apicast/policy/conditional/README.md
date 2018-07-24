# Conditional Policy

- [**Description**](#description)
- [**Conditions**](#conditions)
- [**Example config**](#example-config)

## Description

The conditional policy is a bit different from the rest because it contains a
chain of policies. It defines a condition that is evaluated on each nginx phase
(access, rewrite, log, etc.). When that condition is true, the conditional
policy runs that phase for each of the policies that it contains in its chain.

Let's see an example:

```
APIcast --> Caching --> Conditional --> Upstream

                             |
                             v

                          Headers

                             |
                             v

                       URL Rewriting

```

Let's assume that the conditional policy defines the following condition: `the
request method is POST`. In that case, when the request is a POST, the order of
execution for each phase is:
1) APIcast
2) Caching
3) Headers
4) URL Rewriting
5) Upstream

When the request is not a POST, the order of execution for each phase is:
1) APIcast
2) Caching
3) Upstream


## Conditions

The condition that determines whether to run the policies in the chain of the
conditional policy can be expressed with JSON, and it uses liquid templating.
This is an example that checks whether the request path is `/example_path`:

```json
{
  "left": "{{ uri }}",
  "left_type": "liquid",
  "op": "==",
  "right": "/example_path",
  "right_type": "plain"
}
```

Notice that both the left and right operands can be evaluated either as liquid or
as plain strings. The latter is the default.

We can combine operations with `and` or `or`. This config checks the same as
the one above plus the value of the `Backend` header:

```json
{
  "operations": [
    {
      "left": "{{ uri }}",
      "left_type": "liquid",
      "op": "==",
      "right": "/example_path",
      "right_type": "plain"
    },
    {
      "left": "{{ headers['Backend'] }}",
      "left_type": "liquid",
      "op": "==",
      "right": "test_upstream",
      "right_type": "plain"
    }
  ],
  "combine_op": "and"
}
```

To know more about the details of what is exactly supported please check the
[policy config schema](apicast-policy.json).

These are the variables supported in liquid:
* uri
* host
* remote_addr
* headers['Some-Header']

The updated list of variables can be found [here](../ngx_variable.lua)


## Example config

This is an example configuration. It executes the upstream policy only when
the `Backend` header of the request is `staging`:

```json
{
   "name":"conditional",
   "version":"builtin",
   "configuration":{
      "condition":{
         "operations":[
            {
               "left":"{{ headers['Backend'] }}",
               "left_type":"liquid",
               "op":"==",
               "right":"staging"
            }
         ]
      },
      "policy_chain":[
         {
            "name":"upstream",
            "version": "builtin",
            "configuration":{
               "rules":[
                  {
                     "regex":"/",
                     "url":"http://my_staging_environment"
                  }
               ]
            }
         }
      ]
   }
}

```
