local config_file = assert(io.open('fixtures/config.json')):read('*a')

local configuration = require 'configuration'

local cjson = require 'cjson'

describe('Configuration object', function()
  describe('.parse', function()
    it('returns new configuration object', function()
      assert.same(configuration.new({}), configuration.parse('{}', cjson))
    end)
  end)

  describe('provides information from the config file', function()
    local config = configuration.new({services = { 'a' }})

    it('returns services', function()
      assert.truthy(config.services)
      assert.equals(1, #config.services)
    end)
  end)

  it('.download', function()
    configuration.download('http://user:pass@server.dev:3000')
    configuration.download('http://user@host.com:3000')
    configuration.download('http://:pass@host.com:3000')
  end)
end)
