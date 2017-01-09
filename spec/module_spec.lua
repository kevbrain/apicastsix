local module = require 'module'


describe('module', function()
  describe('.new', function()
    it ('accepts name', function()
      local m = module.new('foobar')

      assert.equal('foobar', m.name)
    end)
  end)

  describe('.call', function()

    it('returns', function()
      package.loaded['foobar'] = { phase = function() return 'foobar' end }

      local m = module.new('foobar')

      local ok, err = m:call('phase')

      assert.truthy(ok)
      assert.falsy(err)
    end)

  end)
end)
