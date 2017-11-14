-- This is a simple policy. The only thing it does is log when it runs each of
-- the nginx phases. It's useful when testing to make sure that all the phases
-- are executed.

local policy = require('policy')
local _M = policy.new('Phase logger')

for _, phase in policy.phases() do
  _M[phase] = function() ngx.log(ngx.DEBUG, 'running phase: ', phase) end
end

return _M
