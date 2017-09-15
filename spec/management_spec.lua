local _M = require('management')
local configuration_store = require('configuration_store')

insulate('Management API', function()

  describe('status', function()
    it('returns false for not configured proxy', function()
      local config = configuration_store.new()
      local status = _M.status(config)

      assert.same('error', status.status)
      assert.same('not configured', status[status.status])
      assert.falsy(status.success)
    end)

    it('returns success for configured proxy without services', function()
      local config = configuration_store.new()
      config:store({ })
      local status = _M.status(config)

      assert.same('warning', status.status)
      assert.same('no services', status[status.status])
      assert.truthy(status.success)
    end)

    it('returns success for configured proxy without services', function()
      local config = configuration_store.new()
      config:add({ id = 42 })
      local status = _M.status(config)

      assert.same('ready', status.status)
      assert.truthy(status.success)
    end)
  end)
end)
