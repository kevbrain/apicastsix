insulate('Configuration object', function()

  insulate('.mock', function()
    local configuration = require 'configuration_loader'
    local mock_loader = require 'configuration_loader.mock'

    it('saves mock configuration', function()
      local config = { 'foo' }
      configuration.mock(config)

      assert.equal(config, mock_loader.config)
    end)
  end)

  describe('.init', function()
    local configuration = require 'configuration_loader'

    it('runs', function()
      local config, err = configuration.init('apicast')

      assert.falsy(config)
      assert.match('missing configuration', err)
    end)
  end)
end)
