local policy = require('apicast.policy')
local _M = policy.new('Rate Limit Policy')

local resty_limit_conn = require('resty.limit.conn')
local resty_limit_req = require('resty.limit.req')
local resty_limit_count = require('resty.limit.count')

local ngx_semaphore = require "ngx.semaphore"
local limit_traffic = require "resty.limit.traffic"
local ts = require ('apicast.threescale_utils')
local tonumber = tonumber
local next = next
local shdict_key = 'limiter'

local new = _M.new

local traffic_limiters = {
  connections = function(config)
    return resty_limit_conn.new(shdict_key, config.conn, config.burst, config.delay)
  end,
  leaky_bucket = function(config)
    return resty_limit_req.new(shdict_key, config.rate, config.burst)
  end,
  fixed_window = function(config)
    return resty_limit_count.new(shdict_key, config.count, config.window)
  end
}

local function try(f, catch_f)
  local status, exception = pcall(f)
  if not status then
    catch_f(exception)
  end
end

local function init_limiter(config)
  local lim, limerr
  try(
    function()
      lim, limerr = traffic_limiters[config.name](config)
    end,
    function(e)
      return nil, e
    end
  )

  return lim, limerr
end

local function redis_shdict(url)
  local options = { url = url }
  local redis, err = ts.connect_redis(options)
  if not redis then
    return nil, err
  end

  return {
    incr = function(_, key, value, init)
      if not init then
        return redis:incrby(key, value), nil
      end
      redis:setnx(key, init)
      return redis:incrby(key, value), nil
    end,
    set = function(_, key, value)
      return redis:set(key, value)
    end,
    expire = function(_, key, exptime)
      local ret = redis:expire(key, exptime)
      if ret == 0 then
        return nil, "not found"
      end
      return true, nil
    end,
    get = function(_, key)
      local val = redis:get(key)
      if type(val) == "userdata" then
        return nil
      end
      return val
    end
  }
end

local function error(logging_only, status_code)
  if not logging_only then
    return ngx.exit(status_code)
  end
end

function _M.new(config)
  local self = new()
  self.config = config or {}
  self.limiters = config.limiters
  self.redis_url = config.redis_url
  self.status_code_rejected = config.status_code_rejected or 429
  self.logging_only = config.logging_only or false

  return self
end

function _M:access()
  local limiters = {}
  local keys = {}

  for _, limiter in ipairs(self.limiters) do
    local lim, initerr = init_limiter(limiter)
    if not lim then
      ngx.log(ngx.ERR, "unknown limiter: ", limiter.name, ", err: ", initerr)
      error(self.logging_only, 500)
      return
    end

    if self.redis_url then
      local rediserr
      lim.dict, rediserr = redis_shdict(self.redis_url)
      if not lim.dict then
        ngx.log(ngx.ERR, "failed to connect Redis: ", rediserr)
        error(self.logging_only, 500)
        return
      end
    end

    table.insert(limiters, lim)
    table.insert(keys, limiter.key)

  end


  local states = {}
  local connections_committed = {}
  local keys_committed = {}

  local delay, comerr = limit_traffic.combine(limiters, keys, states)
  if not delay then
    if comerr == "rejected" then
      ngx.log(ngx.WARN, "Requests over the limit.")
      error(self.logging_only, self.status_code_rejected)
      return
    end
    ngx.log(ngx.ERR, "failed to limit traffic: ", comerr)
    error(self.logging_only, 500)
    return
  end

  for i, lim in ipairs(limiters) do
    if lim.is_committed and lim:is_committed() then
      table.insert(connections_committed, lim)
      table.insert(keys_committed, keys[i])
    end
  end

  if next(connections_committed) ~= nil then
    local ctx = ngx.ctx
    ctx.limiters = connections_committed
    ctx.keys = keys_committed
  end

  if delay > 0 then
    ngx.log(ngx.WARN, 'need to delay by: ', delay, 's, states: ', table.concat(states, ", "))
    ngx.sleep(delay)
  end

end

local function checkin(_, ctx, time, semaphore, redis_url, logging_only)
  local limiters = ctx.limiters
  local keys = ctx.keys
  local latency = tonumber(time)

  for i, lim in ipairs(limiters) do
    if redis_url then
      local rediserr
      lim.dict, rediserr = redis_shdict(redis_url)
      if not lim.dict then
        ngx.log(ngx.ERR, "failed to connect Redis: ", rediserr)
        error(logging_only, 500)
        return
      end
    end
    local conn, err = lim:leaving(keys[i], latency)
    if not conn then
      ngx.log(ngx.ERR, "failed to record the connection leaving request: ", err)
      error(logging_only, 500)
      return
    end
  end

  if semaphore then
    semaphore:post(1)
  end

end

function _M:log()
  local ctx = ngx.ctx
  local limiters = ctx.limiters
  if limiters and next(limiters) ~= nil then
    local semaphore = ngx_semaphore.new()
    ngx.timer.at(0, checkin, ngx.ctx, ngx.var.request_time, semaphore, self.redis_url, self.logging_only)
    semaphore:wait(10)
  end
end

return _M
