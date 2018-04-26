-- This is a {{ policy.name }} description.

local policy = require('apicast.policy')
local _M = policy.new('{{ policy.name }}')

local new = _M.new
--- Initialize a {{ policy.name }}
-- @tparam[opt] table config Policy configuration.
function _M.new(config)
  local self = new(config)
  return self
end

return _M
