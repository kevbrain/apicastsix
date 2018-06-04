local lrucache = require('resty.lrucache')

local TokenCache = require('apicast.policy.token_introspection.tokens_cache')

local function assert_cache_spy_called_with_ttl(cache_spy, ttl)
  -- We only care about the 4th arg (ttl) of the first set() call
  assert.equals(ttl, cache_spy.calls[1].vals[4])
end

describe('token_cache', function()
  local current_time = 1521054560
  local test_token = 'a_token'

  local max_ttl = 10
  local ttl_longer_than_max = max_ttl + 1
  local ttl_shorter_than_max = max_ttl - 1

  -- Storage to inject in the cache so we can spy on it
  local cache_storage
  local cache_storage_spy

  before_each(function()
    stub(ngx, 'time').returns(current_time)

    cache_storage = lrucache.new(10)
    cache_storage_spy = spy.on(cache_storage, 'set')
  end)

  describe('when max TTL is set to 0', function()
    it('does not cache anything', function()
      local cache = TokenCache.new(0)
      cache:set(test_token, { exp = current_time + 60 })
      assert.is_falsy(cache:get(test_token))
    end)
  end)

  describe('when the token info contains an "exp" field', function()
    describe('and max TTL > "exp" TTL ', function()
      it('caches the token with the TTL from "exp"', function()
        local cache = TokenCache.new(max_ttl)
        cache.storage = cache_storage
        local introspection_info = {
          active = true,
          exp = current_time + ttl_shorter_than_max
        }

        cache:set(test_token, introspection_info)

        assert.same(introspection_info, cache:get(test_token))
        assert_cache_spy_called_with_ttl(
          cache_storage_spy, ttl_shorter_than_max)
      end)
    end)

    describe('and max TTL < "exp" TTL', function()
      it('caches the token with the max TTL', function()
        local cache = TokenCache.new(max_ttl)
        cache.storage = cache_storage
        local introspection_info = {
          active = true,
          exp = current_time + ttl_longer_than_max
        }

        cache:set(test_token, introspection_info)

        assert.same(introspection_info, cache:get(test_token))
        assert_cache_spy_called_with_ttl(cache_storage_spy, max_ttl)
      end)
    end)

    describe('and max TTL is nil', function()
      it('caches the token with the TTL from "exp"', function()
        local cache = TokenCache.new()
        cache.storage = cache_storage
        local introspection_info = {
          active = true,
          exp = current_time + ttl_longer_than_max
        }

        cache:set(test_token, introspection_info)

        assert.same(introspection_info, cache:get(test_token))
        assert_cache_spy_called_with_ttl(
          cache_storage_spy, ttl_longer_than_max)
      end)
    end)
  end)

  describe('when the token info does not contain an "exp" field', function()
    describe('and there is a max TTL configured', function()
      it('caches the token with the max TTL', function()
        local cache = TokenCache.new(max_ttl)
        cache.storage = cache_storage
        local introspection_info = { active = true, }

        cache:set(test_token, introspection_info)

        assert.same(introspection_info, cache:get(test_token))
        assert_cache_spy_called_with_ttl(cache_storage_spy, max_ttl)

      end)
    end)

    describe('and there is not a max TTL configured', function()
      it('does not cache the token', function()
        local cache = TokenCache.new()
        cache.storage = cache_storage
        local introspection_info = { active = true, }

        cache:set(test_token, introspection_info)

        assert.is_falsy(cache:get(test_token))
      end)
    end)
  end)
end)
