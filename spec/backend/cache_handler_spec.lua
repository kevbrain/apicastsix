
local _M = require('backend.cache_handler')
local lrucache = require('resty.lrucache')


describe('Cache Handler', function()

  describe('.new', function()
    it('has a default handler', function()
      local handler = _M.new()
      assert.equal(assert(_M.handlers.default), handler.handler)
    end)

    it('sets a handler', function()
      local handler = _M.new('strict')

      assert.equal('strict', handler.handler)
    end)
  end)

  describe('call', function()
    it('calls handler on runtime', function()
      local handler = _M.new('test-fake')

      stub(_M.handlers, 'test-fake', function() return 'return value' end)

      assert.equal('return value', handler())
    end)
  end)

  describe('strict', function()
    local handler = _M.handlers.strict

    it('caches successful response', function()
      local cache = lrucache.new(1)
      ngx.var = { cached_key = nil }

      assert.truthy(handler(cache, 'foobar', { status = 200 }))

      assert.equal(200, cache:get('foobar'))
    end)

    it('not caches in post action', function()
      local cache = lrucache.new(1)
      ngx.var = { cached_key = 'foobar' } -- means it is performed in post_action

      assert.truthy(handler(cache, 'foobar', { status = 200 }))

      assert.falsy(cache:get('foobar'))
    end)

    it('deletes cache on forbidden response', function()
      local cache = lrucache.new(1)
      cache:set('foobar', 200)

      assert.falsy(handler(cache, 'foobar', { status = 403 }))

      assert.falsy(cache:get('foobar'))
    end)

    it('deletes cache on server errors', function()
      local cache = lrucache.new(1)
      cache:set('foobar', 200)

      assert.falsy(handler(cache, 'foobar', { status = 503 }))

      assert.falsy(cache:get('foobar'))
    end)
  end)


  describe('resilient', function()
    local handler = _M.handlers.resilient

    it('caches successful response', function()
      local cache = lrucache.new(1)

      assert.truthy(handler(cache, 'foobar', { status = 200 }))

      assert.equal(200, cache:get('foobar'))
    end)

    it('caches forbidden response', function()
      local cache = lrucache.new(1)

      assert.falsy(handler(cache, 'foobar', { status = 403 }))

      assert.equal(403, cache:get('foobar'))
    end)

    it('not caches server errors', function()
      local cache = lrucache.new(1)

      assert.falsy(handler(cache, 'foobar', { status = 503 }))

      assert.falsy(cache:get('foobar'))
    end)

    it('not overrides cache on server errors', function()
      local cache = lrucache.new(1)

      cache:set('foobar', 200)

      assert.falsy(handler(cache, 'foobar', { status = 503 }))

      assert.equal(200, cache:get('foobar'))
    end)
  end)

end)
