--- Echo policy
-- Print the request back to the client and optionally set a status code.
-- Also can interrupt the execution and skip the current phase or
-- the whole processing of the request.

local _M = require('apicast.policy').new('Echo Policy')

local tonumber = tonumber
local new = _M.new

function _M.new(configuration)
  local policy = new(configuration)

  if configuration then
    policy.status = tonumber(configuration.status)
    policy.exit = configuration.exit
  end

  return policy
end

function _M.content()
  ngx.say(ngx.var.request)
end

function _M:rewrite()
  if self.status then
    ngx.status = self.status
  end

  if self.exit == 'request' then
    return ngx.exit(ngx.status)
  elseif self.exit == 'phase' then
    return ngx.exit(0)
  end
end

return _M
