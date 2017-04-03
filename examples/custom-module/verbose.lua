local apicast = require('apicast')

local _M = { _VERSION = '0.0' }

function _M.new()
  return setmetatable(_M, { __index = apicast.new() })
end

function _M.log()
  ngx.log(ngx.WARN,
    'upstream response time: ', ngx.var.upstream_response_time, ' ',
    'upstream connect time: ', ngx.var.upstream_connect_time)
end

return _M