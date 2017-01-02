local configuration = require 'configuration_loader'

describe('Configuration object', function()

  describe('.download', function()
    it('returns error on missing endpoint', function()
      assert.same({nil, 'missing endpoint'}, { configuration.download() })
    end)

    it('returns error on invalid URI', function()
      assert.same({nil, 'invalid endpoint'}, { configuration.download('foobar') })
    end)

    it('returns error on invalid URI', function()
      assert.same({nil, 'connection refused'}, { configuration.download('http://127.0.0.1:1234/config/') })
    end)


    it('.download', function()
      configuration.download('http://user:pass@localhost:3000')
      configuration.download('https://user@localhost')
      configuration.download('http://:pass@lvh.me:3000')
    end)
  end)

  describe('.read', function()
    it('ignores empty path', function()
      assert.same({nil, 'missing path'}, { configuration.read() })
      assert.same({nil, 'missing path'}, { configuration.read('') })
    end)
  end)
end)
