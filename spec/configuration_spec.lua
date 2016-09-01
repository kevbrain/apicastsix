local config_file = assert(io.open('fixtures/config.json')):read('*a')

local configuration = require 'configuration'

local cjson = require 'cjson'

describe('Configuration object', function()
  describe('.parse', function()
    it('returns new configuration object', function()
      assert.same(configuration.new({}), configuration.parse('{}', cjson))
    end)

    it('works with table', function()
      assert.same(configuration.new({}), configuration.parse({}))
    end)
  end)

  describe('provides information from the config file', function()
    local config = configuration.new({services = { 'a' }})

    it('returns services', function()
      assert.truthy(config.services)
      assert.equals(1, #config.services)
    end)
  end)

  describe('.download', function()
    it('returns error on missing endpoint', function()
      assert.same({nil, 'missing endpoint'}, { configuration.download() })
    end)

    it('returns error on invalid URI', function()
      assert.same({nil, 'invalid endpoint'}, { configuration.download('foobar') })
    end)
  end)

  it('.download', function()
    configuration.download('http://user:pass@localhost:3000')
    configuration.download('https://user@localhost')
    configuration.download('http://:pass@lvh.me:3000')
  end)
end)
