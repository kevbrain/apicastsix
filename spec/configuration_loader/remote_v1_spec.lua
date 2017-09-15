local loader = require 'configuration_loader.remote_v1'

describe('Configuration object', function()

  describe('.download', function()
    it('returns error on missing endpoint', function()
      assert.same({nil, 'missing endpoint'}, { loader.download() })
    end)

    it('returns error on invalid URI', function()
      assert.same({nil, 'invalid endpoint'}, { loader.download('foobar') })
    end)

    it('returns error on invalid URI', function()
      assert.same({nil, 'connection refused'}, { loader.download('http://127.0.0.1:1234/config/') })
    end)


    it('.download', function()
      loader.download('http://user:pass@localhost:3000')
      loader.download('https://user@localhost')
      loader.download('http://:pass@lvh.me:3000')
    end)

    it('decodes config #network', function()
      assert(loader.download('http://127.0.0.1:1984/json'))
    end)
  end)
end)
