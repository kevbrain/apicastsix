local errors = require 'apicast.errors'
local Service = require 'apicast.configuration.service'

describe('Errors', function()
  describe('.limits_exceeded', function()
    before_each(function()
      ngx.var = {}
      ngx.header = {}
    end)

    local test_service = Service.new({ id = 1 })

    it('sets the Retry-After header when a value for it is received', function()
      local retry_after = 60

      errors.limits_exceeded(test_service, retry_after)

      assert.equals(retry_after, ngx.header['Retry-After'])
    end)

    it('does not set the Retry-After header when a value for it is not received', function()
      errors.limits_exceeded(test_service)

      assert.is_nil(ngx.header['Retry-After'])
    end)
  end)
end)
