local module = require 'module'

describe('module', function()
  before_each(function() module.flush() end)

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

  describe('.load', function()
    local new = { rewrite = function() end }
    local foobar = { new = function() return new end, init = function() end }

    it('returns module instance', function()
      package.loaded['foobar'] = foobar

      local f, mod = module.load('foobar', 'rewrite')

      assert(f, mod)
      assert.equal(new, mod)
      assert.equal(new.rewrite, f)
    end)

    it('caches the instance', function()
      package.loaded['foobar'] = foobar
      stub(foobar, 'new').returns(new)

      local _, mod = assert(module.load('foobar', 'rewrite'))
      assert(module.load('foobar', 'rewrite'))

      assert.spy(foobar.new).was.called(1)
      assert.equal(mod, ngx.ctx.module)
    end)

    it('does not try module instance for init', function()
      package.loaded['foobar'] = foobar

      local f, mod = module.load('foobar', 'init')

      assert(f, mod)
      assert.falsy(mod)
      assert.equal(foobar.init, f)
    end)
  end)
end)
