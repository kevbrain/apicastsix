local apicast = require('apicast').new()

local _M = { _VERSION = apicast._VERSION, _NAME = 'APIcast with CORS' }

local mt = { __index = setmetatable(_M, { __index = apicast }) }

function _M.new()
  return setmetatable({}, mt)
end

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

local function cors_preflight()
  return (
    ngx.req.get_method() == 'OPTIONS' and
    ngx.var.http_origin and
    ngx.var.http_access_control_request_method
  )
end

-- header_filter is used to manipulate response headers
function _M.header_filter()
  set_cors_headers()

  return apicast:header_filter()
end

-- rewrite is the first phase executed and can hijack the whole request handling
function _M.rewrite()
  -- for CORS preflight sent by the browser, return a 204 status code
  if cors_preflight() then
    return cors_preflight_response()
  else
    -- if the request is not CORS preflight jut continue with APIcast flow
    return apicast:rewrite()
  end
end

return _M
