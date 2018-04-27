--- Policy Config Validator
-- @module policy_config_validator
-- Validates a policy configuration against a policy config JSON schema.

local jsonschema = require('jsonschema')

local _M = { }

--- Validate a policy configuration
-- Checks if a policy configuration is valid according to the given schema.
-- @tparam table config Policy configuration
-- @tparam table config_schema Policy configuration schema
-- @treturn boolean True if the policy configuration is valid. False otherwise.
-- @treturn string Error message only when the policy config is invalid.
function _M.validate_config(config, config_schema)
  local validator = jsonschema.generate_validator(config_schema or {})
  return validator(config or {})
end

return _M
