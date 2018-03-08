local policy = require('apicast.policy')
local _M = policy.new('Rate Limiting to Service Policy')

local ts = require('apicast.threescale_utils')
local tonumber = tonumber

local new = _M.new

function _M.new(config)
  local self = new()
  self.config = config or {}

  self.limit = tonumber(config.limit)
  self.period = tonumber(config.period)
  self.service_name = config.service_name

  if self.limit <= 0 or self.period <= 0 then
    ngx.log(ngx.ERR, "Invalid configuration.")
    return ngx.exit(500)
  end

  return self
end

function _M:rewrite()
  local red, connerr = ts.connect_redis()
  if not red and connerr then
    ngx.log(ngx.ERR, "failed to connect Redis: ", connerr)
    return ngx.exit(500)
  end

  local ok, seterr = red:set(self.service_name, self.limit, 'EX', self.period, 'NX')
  if not ok or seterr then
    ngx.log(ngx.ERR, "failed to set limit: ", seterr)
    return ngx.exit(500)
  end

  local remaining, decrerr = red:decr(self.service_name)
  if not remaining or decrerr then
    ngx.log(ngx.ERR, "failed to decrease limit: ", decrerr)
    return ngx.exit(500)
  end

  if remaining < 0 then
    ngx.log(ngx.ERR, "Requests over the limit.")
    ngx.header['X-RateLimit-Limit'] = self.limit
    ngx.header['X-RateLimit-Remaining'] = 0
    ngx.header['X-RateLimit-Reset'] = os.time(os.date("!*t")) + red:ttl(self.service_name)
    return ngx.exit(429)
  end

  ngx.header['X-RateLimit-Limit'] = self.limit
  ngx.header['X-RateLimit-Remaining'] = remaining
  ngx.header['X-RateLimit-Reset'] = os.time(os.date("!*t")) + red:ttl(self.service_name)
end

return _M
