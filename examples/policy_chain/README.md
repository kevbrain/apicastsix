# Configure Policy Chain

Environment configuration can define the global policy chain. You can provide custom chain or insert policies to the default one.

## Using Echo Policy

[Echo policy](../../gateway/src/apicast/policy/echo) accepts configuration option to terminate the request phase. See the example in [`configuration.lua`](./configuration.lua).

You can start it as:

```shell
ECHO_STATUS=202 bin/apicast --environment examples/policy_chain/configuration.lua
```
