local policy = require('apicast.policy')
local _M = policy.new('Echo Policy')

function _M.rewrite()
  ngx.say(ngx.var.request)
  ngx.exit(0)
end

return _M
