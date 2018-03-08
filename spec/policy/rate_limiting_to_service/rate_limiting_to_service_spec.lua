local RateLimitPolicy = require('apicast.policy.rate_limiting_to_service')
local env = require 'resty.env'

describe('Rate limit policy', function()
  local ngx_exit_spy

  setup(function()
    ngx_exit_spy = spy.on(ngx, 'exit')
    env.set('REDIS_URL', 'redis://localhost:6379/1')
  end)
  before_each(function()
    ngx.header = {}
  end)
  describe('.new', function()
    it('invalid limit', function()
      local config = {
        limit = 0,
        period = 10,
        service_name = 'service_unit_test_1'
      }
      rate_limit_policy = RateLimitPolicy.new(config)

      assert.spy(ngx_exit_spy).was_called_with(500)
      assert.is_nil(ngx.header['X-RateLimit-Limit'])
      assert.is_nil(ngx.header['X-RateLimit-Remaining'])
      assert.is_nil(ngx.header['X-RateLimit-Reset'])
    end)
    it('invalid period', function()
      local config = {
        limit = 10,
        period = 0,
        service_name = 'service_unit_test_2'
      }
      rate_limit_policy = RateLimitPolicy.new(config)

      assert.spy(ngx_exit_spy).was_called_with(500)
      assert.is_nil(ngx.header['X-RateLimit-Limit'])
      assert.is_nil(ngx.header['X-RateLimit-Remaining'])
      assert.is_nil(ngx.header['X-RateLimit-Reset'])
    end)
  end)
  describe('.rewrite', function()
    it('set new limit and decrease the limit', function()
      local config = {
        limit = 10,
        period = 10,
        service_name = 'service_unit_test_3'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:rewrite()

      assert.same(10, ngx.header['X-RateLimit-Limit'])
      assert.same(9, ngx.header['X-RateLimit-Remaining'])
      assert.is_not_nil(ngx.header['X-RateLimit-Reset'])

      rate_limit_policy:rewrite()

      assert.same(10, ngx.header['X-RateLimit-Limit'])
      assert.same(8, ngx.header['X-RateLimit-Remaining'])
      assert.is_not_nil(ngx.header['X-RateLimit-Reset'])
    end)
    it('return 429 code', function()
      local config = {
        limit = 1,
        period = 5,
        service_name = 'service_unit_test_4'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:rewrite()

      assert.same(1, ngx.header['X-RateLimit-Limit'])
      assert.same(0, ngx.header['X-RateLimit-Remaining'])
      assert.is_not_nil(ngx.header['X-RateLimit-Reset'])

      rate_limit_policy:rewrite()

      assert.spy(ngx_exit_spy).was_called_with(429)
      assert.same(1, ngx.header['X-RateLimit-Limit'])
      assert.same(0, ngx.header['X-RateLimit-Remaining'])
      assert.is_not_nil(ngx.header['X-RateLimit-Reset'])

      local start = os.time()
      while os.time() - start < 5 do end

      rate_limit_policy:rewrite()

      assert.same(1, ngx.header['X-RateLimit-Limit'])
      assert.same(0, ngx.header['X-RateLimit-Remaining'])
      assert.is_not_nil(ngx.header['X-RateLimit-Reset'])
    end)
  end)
end)
