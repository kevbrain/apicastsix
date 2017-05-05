local apicast = require('apicast').new()

local _M = { _VERSION = '0.0' }
local mt = { __index = setmetatable(_M, { __index = apicast }) }

function _M.new()
  return setmetatable({}, mt)
end

function _M.log()
  ngx.log(ngx.WARN,
    'upstream response time: ', ngx.var.upstream_response_time, ' ',
    'upstream connect time: ', ngx.var.upstream_connect_time)
  return apicast:log()
end

return _M
