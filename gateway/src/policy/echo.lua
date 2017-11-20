local policy = require('policy')
local _M = policy.new('Echo Policy')

function _M.access()
  ngx.log(ngx.DEBUG, ngx.var.request)
end

return _M
