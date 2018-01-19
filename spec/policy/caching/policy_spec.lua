local resty_lrucache = require('resty.lrucache')

describe('policy', function()
  describe('.new', function()
    local cache = resty_lrucache.new(1)

    it('disables caching when caching type is not specified', function()
      local caching_policy = require('apicast.policy.caching').new({})
      local ctx = {}
      caching_policy:rewrite(ctx)

      ctx.cache_handler(cache, 'a_key', { status = 200 }, nil)
      assert.is_nil(cache:get('a_key'))
    end)

    it('disables caching when invalid caching type is specified', function()
      local config = { caching_type = 'invalid_caching_type' }
      local caching_policy = require('apicast.policy.caching').new(config)
      local ctx = {}
      caching_policy:rewrite(ctx)

      ctx.cache_handler(cache, 'a_key', { status = 200 }, nil)
      assert.is_nil(cache:get('a_key'))
    end)
  end)

  describe('.access', function()
    describe('when configured as strict', function()
      local caching_policy
      local cache
      local ctx  -- the caching policy will add the handler here

      before_each(function()
        local config = { caching_type = 'strict' }
        caching_policy = require('apicast.policy.caching').new(config)
        ctx = { }
        caching_policy:rewrite(ctx)
        cache = resty_lrucache.new(1)
      end)

      it('caches authorized requests', function()
        ctx.cache_handler(cache, 'a_key', { status = 200 }, nil)
        assert.equals(200, cache:get('a_key'))
      end)

      it('clears the cache entry for a request when it is denied', function()
        cache:set('a_key', 200)

        ctx.cache_handler(cache, 'a_key', { status = 403 }, nil)
        assert.is_nil(cache:get('a_key'))
      end)

      it('clears the cache entry for a request when it fails', function()
        cache:set('a_key', 200)

        ctx.cache_handler(cache, 'a_key', { status = 500 }, nil)
        assert.is_nil(cache:get('a_key'))
      end)
    end)

    describe('when configured as resilient', function()
      local caching_policy
      local cache
      local ctx  -- the caching policy will add the handler here

      before_each(function()
        local config = { caching_type = 'resilient' }
        caching_policy = require('apicast.policy.caching').new(config)
        ctx = { }
        caching_policy:rewrite(ctx)
        cache = resty_lrucache.new(1)
      end)

      it('caches authorized requests', function()
        ctx.cache_handler(cache, 'a_key', { status = 200 }, nil)
        assert.equals(200, cache:get('a_key'))
      end)

      it('caches denied requests', function()
        ctx.cache_handler(cache, 'a_key', { status = 403 }, nil)
        assert.equals(403, cache:get('a_key'))
      end)

      it('does not clear the cache entry for a request when it fails', function()
        cache:set('a_key', 200)

        ctx.cache_handler(cache, 'a_key', { status = 500 }, nil)
        assert.equals(200, cache:get('a_key'))
      end)
    end)

    describe('when configured as allow', function()
      local caching_policy
      local cache
      local ctx  -- the caching policy will add the handler here

      before_each(function()
        local config = { caching_type = 'allow' }
        caching_policy = require('apicast.policy.caching').new(config)
        ctx = { }
        caching_policy:rewrite(ctx)
        cache = resty_lrucache.new(1)
      end)

      it('caches authorized requests', function()
        ctx.cache_handler(cache, 'a_key', { status = 200 }, nil)
        assert.equals(200, cache:get('a_key'))
      end)

      it('caches denied requests', function()
        ctx.cache_handler(cache, 'a_key', { status = 403 }, nil)
        assert.equals(403, cache:get('a_key'))
      end)

      describe('and backend returns 5XX', function()
        it('does not invalidate the cache entry if there was a 4XX', function()
          cache:set('a_key', 403)
          ctx.cache_handler(cache, 'a_key', { status = 500 }, nil)
          assert.equals(403, cache:get('a_key'))
        end)

        it('caches a 200 if there was nothing in the cache entry', function()
          ctx.cache_handler(cache, 'a_key', { status = 500 }, nil)
          assert.equals(200, cache:get('a_key'))
        end)

        it('caches a 200 if there was something != 4XX in the cache entry', function()
          cache:set('a_key', 200)
          ctx.cache_handler(cache, 'a_key', { status = 500 }, nil)
          assert.equals(200, cache:get('a_key'))
        end)
      end)
    end)

    describe('when disabled', function()
      local caching_policy
      local cache
      local ctx

      setup(function()
        local config = { caching_type = 'none' }
        caching_policy = require('apicast.policy.caching').new(config)
        ctx = {}
        caching_policy:rewrite(ctx)
        cache = resty_lrucache.new(1)
      end)

      it('does not cache anything', function()
        ctx.cache_handler(cache, 'a_key', { status = 200 }, nil)
        assert.is_nil(cache:get('a_key'))
      end)
    end)
  end)
end)
