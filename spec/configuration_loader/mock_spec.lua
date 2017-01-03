local loader = require 'configuration_loader.mock'

describe('Configuration Mock loader', function()
  describe('.call', function()
    after_each(function() loader.config = nil end)

    it('returns saved config', function()
      local config = { 'config ' }

      loader.config = config

      assert.equal(config, loader.call())
    end)

    it('saves config', function()
      local config = { 'config' }

      loader.save(config)

      assert.equal(config, loader.config)
    end)
  end)
end)
