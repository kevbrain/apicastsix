local _M = require('apicast.cli.environment')

describe('Environment Configuration', function ()

  describe('.new', function()
    it('accepts default', function()
      local default = { foo = 'bar' }
      local env = _M.new(default)

      assert.contains(default, env:context())
    end)
  end)

end)
