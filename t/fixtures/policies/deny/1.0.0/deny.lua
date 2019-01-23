local _M = require('apicast.policy').new('deny', '1.0.0')

local new = _M.new

function _M.new(configuration)
  local policy = new(configuration)
  policy.phase = configuration.phase
  return policy
end

function _M:rewrite()
  if self.phase == 'rewrite' then
    ngx.exit(403)
  end
end

function _M:access()
  if self.phase == 'access' then
    ngx.exit(403)
  end
end

return _M
