local module = require 'module'


describe('module', function()
  describe('.new', function()
    it ('accepts name', function()
      local m = module.new('foobar')

      assert.equal('foobar', m.name)
    end)
  end)

  describe('.call', function()
    after_each(function() module.flush() end)

    it('returns', function()
      package.loaded['foobar'] = { phase = function() return 'foobar' end }

      local m = module.new('foobar')

      local ok, err = m:call('phase')

      assert.truthy(ok)
      assert.falsy(err)
    end)

  end)

  describe(':require', function()
    it('returns a module', function()
      local foobar = { _VERSION = '1.1', _NAME = 'Foo Bar' }
      package.loaded['foobar'] = foobar

      local m = module.new('foobar')

      local mod, err = m:require()

      assert.equal(mod, foobar)
      assert.falsy(err)
    end)
  end)
end)
