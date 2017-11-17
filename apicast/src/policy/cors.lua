local policy = require('policy')
local _M = policy.new('CORS Policy')

local function set_cors_headers()
  local origin = ngx.var.http_origin

  if not origin then return end

  ngx.header['Access-Control-Allow-Headers'] = ngx.var.http_access_control_request_headers
  ngx.header['Access-Control-Allow-Methods'] = ngx.var.http_access_control_request_method
  ngx.header['Access-Control-Allow-Origin'] = origin
  ngx.header['Access-Control-Allow-Credentials'] = 'true'
end

local function cors_preflight_response()
  set_cors_headers()
  ngx.status = 204
  ngx.exit(ngx.status)
end

local function is_cors_preflight()
  return ngx.req.get_method() == 'OPTIONS' and
         ngx.var.http_origin and
         ngx.var.http_access_control_request_method
end

function _M.rewrite()
  if is_cors_preflight() then
    return cors_preflight_response()
  end
end

function _M.header_filter()
  set_cors_headers()
end

return _M
