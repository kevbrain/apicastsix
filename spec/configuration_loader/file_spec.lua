local loader = require 'configuration_loader.file'

describe('Configuration File loader', function()
  describe('.call', function()
    it('ignores empty path', function()
      assert.same({nil, 'missing path'}, { loader.call() })
      assert.same({nil, 'missing path'}, { loader.call('') })
    end)

    it('reads a file', function()
      assert.truthy(loader.call('fixtures/config.json'))
    end)
  end)
end)
