local _M = require('apicast.policy').new('example_policy', '1.0.0')

local new = _M.new

function _M.new(configuration)
  local policy = new(configuration)

  policy.message = ''

  if configuration then
    policy.message = configuration.message
  end

  return policy
end

function _M:content()
  ngx.say(self.message)
end

return _M
