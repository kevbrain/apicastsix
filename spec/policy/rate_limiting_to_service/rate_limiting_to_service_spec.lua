local RateLimitPolicy = require('apicast.policy.rate_limiting_to_service')
local function init_val()
  ngx.var = {}
  ngx.var.request_time = '0.060'

  ngx.shared.limitter = {}
  ngx.shared.limitter.get = function(_, key)
    return ngx.shared.limitter[key]
  end
  ngx.shared.limitter.set = function(_, key, val)
    ngx.shared.limitter[key] = val
  end
  ngx.shared.limitter.incr = function(_, key, val, init)
    local v = ngx.shared.limitter[key]
    if not v then
      ngx.shared.limitter[key] = val + init
    else
      ngx.shared.limitter[key] = v + val
    end
    return ngx.shared.limitter[key]
  end
  ngx.shared.limitter.expire = function(_, _, _)
    return true, nil
  end
end

describe('Rate limit policy', function()
  local ngx_exit_spy
  local ngx_sleep_spy

  setup(function()
    ngx_exit_spy = spy.on(ngx, 'exit')
    ngx_sleep_spy = spy.on(ngx, 'sleep')
  end)

  before_each(function()
    local redis = require('resty.redis'):new()
    redis:connect('127.0.0.1', 6379)
    redis:select(1)
    redis:del('test1', 'test2', 'test3')
    init_val()
  end)

  describe('.access', function()
    it('success with multiple limiters', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.conn', key = 'test1', values = {20, 10, 0.5}},
          {limitter = 'resty.limit.req', key = 'test2', values = {18, 9}},
          {limitter = 'resty.limit.count', key = 'test3', values = {10, 10}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
    end)
    it('invalid limitter class name', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.invalid', key = 'test1', values = {20, 10, 0.5}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      assert.spy(ngx_exit_spy).was_called_with(500)
    end)
    it('invalid limitter values', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.count', key = 'test1', values = {0, 10}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      assert.spy(ngx_exit_spy).was_called_with(500)
    end)
    it('no redis url', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.conn', key = 'test1', values = {20, 10, 0.5}}
        }
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      assert.spy(ngx_exit_spy).was_called_with(500)
    end)
    it('invalid redis url', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.conn', key = 'test1', values = {20, 10, 0.5}}
        },
        redis_url = 'redis://invalidhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      assert.spy(ngx_exit_spy).was_called_with(500)
    end)
    it('rejected (conn)', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.conn', key = 'test1', values = {1, 0, 0.5}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      rate_limit_policy:access()
      assert.spy(ngx_exit_spy).was_called_with(429)
    end)
    it('rejected (req)', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.req', key = 'test1', values = {1, 0}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      rate_limit_policy:access()
      assert.spy(ngx_exit_spy).was_called_with(429)
    end)
    it('rejected (count)', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.count', key = 'test1', values = {1, 10}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      rate_limit_policy:access()
      assert.spy(ngx_exit_spy).was_called_with(429)
    end)
    it('delay (conn)', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.conn', key = 'test1', values = {1, 1, 2}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      rate_limit_policy:access()
      assert.spy(ngx_sleep_spy).was_called_more_than(0.001)
    end)
    it('delay (req)', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.req', key = 'test1', values = {1, 1}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      rate_limit_policy:access()
      assert.spy(ngx_sleep_spy).was_called_more_than(0.001)
    end)
  end)
  describe('.log', function()
    it('success in leaving', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.conn', key = 'test1', values = {20, 10, 0.5}}
        }
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      rate_limit_policy:log()
    end)
    it('success in leaving with redis', function()
      local config = {
        limitters = {
          {limitter = 'resty.limit.conn', key = 'test1', values = {20, 10, 0.5}}
        },
        redis_url = 'redis://localhost:6379/1'
      }
      local rate_limit_policy = RateLimitPolicy.new(config)
      rate_limit_policy:access()
      rate_limit_policy:log()
    end)
  end)
end)
