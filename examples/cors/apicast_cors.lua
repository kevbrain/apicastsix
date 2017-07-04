local apicast = require('apicast').new()

local _M = { _VERSION = '3.0.0', _NAME = 'APIcast with CORS' }

local mt = { __index = setmetatable(_M, { __index = apicast }) }

function _M.new()
  return setmetatable({}, mt)
end

local function set_cors_headers()
  ngx.header['Access-Control-Allow-Headers'] = ngx.var.http_access_control_request_headers
  ngx.header['Access-Control-Allow-Methods'] = ngx.var.http_access_control_request_method
  ngx.header['Access-Control-Allow-Origin'] = ngx.var.http_origin
  ngx.header['Access-Control-Allow-Credentials'] = 'true'
end

local function cors_preflight_response()
  local cors_preflight = ngx.var.request_method == 'OPTIONS' and
                          ngx.var.http_origin and ngx.var.http_access_control_request_method

  -- for CORS preflight sent by the browser, return a 204 status code
  if cors_preflight then
    set_cors_headers()
    ngx.status = 204
    return ngx.exit(ngx.status)
  end
end

function _M.rewrite()
  cors_preflight_response()
  return apicast:rewrite()
end

return _M
