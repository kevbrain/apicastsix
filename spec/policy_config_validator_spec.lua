local cjson = require('cjson')
local policy_config_validator = require('apicast.policy_config_validator')

describe('policy_config_validator', function()
  -- We use the echo policy schema as an example for the tests.
  local test_config_schema = cjson.decode([[
    {
      "type": "object",
      "properties": {
        "status": {
          "description": "HTTP status code to be returned",
          "type": "integer"
        },
        "exit": {
          "description": "Exit mode",
          "type": "string",
          "oneOf": [{
              "enum": ["request"],
              "description": "Interrupts the processing of the request."
            },
            {
              "enum": ["set"],
              "description": "Only skips the rewrite phase."
            }
          ]
        }
      }
    }
  ]])

  it('returns true with a config that conforms with the schema', function()
    local valid_config = { status = 200, exit = "request" }

    local is_valid, err = policy_config_validator.validate_config(
      valid_config, test_config_schema)

    assert.is_true(is_valid)
    assert.is_nil(err)
  end)

  it('returns false with a config that does not conform with the schema', function()
    local invalid_config = { status = "not_an_integer" }

    local is_valid, err = policy_config_validator.validate_config(
      invalid_config, test_config_schema)

    assert.is_false(is_valid)
    assert.is_not_nil(err)
  end)

  it('returns true when the schema is empty', function()
    assert.is_true(policy_config_validator.validate_config({ a_param = 1 }, {}))
  end)

  it('returns true when the schema is nil', function()
    assert.is_true(policy_config_validator.validate_config({ a_param = 1 }, nil))
  end)
end)
