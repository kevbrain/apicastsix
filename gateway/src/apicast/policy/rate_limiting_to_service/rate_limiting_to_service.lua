local policy = require('apicast.policy')
local _M = policy.new('Rate Limiting to Service Policy')

local ngx_semaphore = require "ngx.semaphore"
local limit_traffic = require "resty.limit.traffic"
local resty_redis = require('resty.redis')
local tonumber = tonumber
local next = next
local shdict_key = 'limitter'

local new = _M.new

function _M.new(config)
  local self = new()
  self.config = config or {}
  self.limitters = config.limitters
  self.redis_info = config.redis_info
  return self
end

local function redis_shdict(host, port, db)
  local redis = assert(resty_redis:new())

  local ok, connerr = redis:connect(host or '127.0.0.1', port or 6379)
  if not ok then
    return nil, connerr
  end

  ok = redis:select(db or 0)
  if not ok then
    return nil, "failed to select db"
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

local function try(f, catch_f)
  local status, exception = pcall(f)
  if not status then
    catch_f(exception)
  end
end

function _M:access()
  local limitters = {}
  local keys = {}
  local states = {}

  local limitters_limit_conn = {}
  local keys_limit_conn = {}

  local limitters_limit_conn_committed = {}
  local keys_limit_conn_committed = {}

  if not self.redis_info then
    ngx.log(ngx.ERR, "No Redis information.")
    return ngx.exit(500)
  end

  for _, limitter in ipairs(self.limitters) do
    local limit
    local class_not_found = false
    try(
      function()
        limit = require (limitter.limitter)
      end,
      function(e)
        ngx.log(ngx.ERR, "failed to find module: ", e)
        class_not_found = true
      end
    )
    if class_not_found then
      return ngx.exit(500)
    end

    local lim, limerr
    local failed_to_instantiate = false
    try(
      function()
        lim, limerr = limit.new(shdict_key, unpack(limitter.values))
        if not lim then
          ngx.log(ngx.ERR, "failed to instantiate limitter: ", limerr)
          failed_to_instantiate = true
        end
      end,
      function(e)
        ngx.log(ngx.ERR, "failed to instantiate limitter: ", e)
        failed_to_instantiate = true
      end
    )
    if failed_to_instantiate then
      return ngx.exit(500)
    end

    local rediserr
    lim.dict, rediserr = redis_shdict(self.redis_info.host, self.redis_info.port, self.redis_info.db)
    if not lim.dict then
      ngx.log(ngx.ERR, "failed to connect Redis: ", rediserr)
      return ngx.exit(500)
    end

    limitters[#limitters + 1] = lim
    keys[#keys + 1] = limitter.key

    if limitter.limitter == "resty.limit.conn" then
      limitters_limit_conn[#limitters_limit_conn + 1] = lim
      keys_limit_conn[#keys_limit_conn + 1] = limitter.key
    end
  end

  local delay, comerr = limit_traffic.combine(limitters, keys, states)
  if not delay then
    if comerr == "rejected" then
      ngx.log(ngx.ERR, "Requests over the limit.")
      return ngx.exit(429)
    end
    ngx.log(ngx.ERR, "failed to limit traffic: ", comerr)
    return ngx.exit(500)
  end

  for i, lim in ipairs(limitters_limit_conn) do
    if lim:is_committed() then
      limitters_limit_conn_committed[#limitters_limit_conn_committed + 1] = lim
      keys_limit_conn_committed[#keys_limit_conn_committed + 1] = keys_limit_conn[i]
    end
  end

  if next(limitters_limit_conn_committed) ~= nil then
    local ctx = ngx.ctx
    ctx.limitters = limitters_limit_conn_committed
    ctx.keys = keys_limit_conn_committed
  end

  if delay >= 0.001 then
    ngx.log(ngx.WARN, 'need to delay by: ', delay, 's')
    ngx.sleep(delay)
  end

end

local function checkin(_, ctx, time, semaphore, redis_info)
  local limitters = ctx.limitters
  local keys = ctx.keys

  for i, lim in ipairs(limitters) do
    local rediserr
    lim.dict, rediserr = redis_shdict(redis_info.host, redis_info.port, redis_info.db)
    if not lim.dict then
      ngx.log(ngx.ERR, "failed to connect Redis: ", rediserr)
      return ngx.exit(500)
    end

    local latency = tonumber(time)
    local conn, err = lim:leaving(keys[i], latency)
    if not conn then
      ngx.log(ngx.ERR, "failed to record the connection leaving request: ", err)
      return
    end
  end

  if semaphore then
    semaphore:post(1)
  end
end

function _M:log()
  local ctx = ngx.ctx
  local limitters = ctx.limitters
  if limitters and next(limitters) ~= nil then
    local semaphore = ngx_semaphore.new()
    ngx.timer.at(0, checkin, ngx.ctx, ngx.var.request_time, semaphore, self.redis_info)
    semaphore:wait(10)
  end
end

return _M
