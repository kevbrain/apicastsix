-- This module customizes the APIcast authorization logic, and returns a different response code 
-- and message if the authorization failed because the application reached its usage limits.
-- In other cases the behavior is as in standard APIcast.
-- The status code, error message and the content-type header can be configured
-- in the 'usage_limits_error' object below:

local usage_limits_error = {
  status = 429,
  content_type = 'text/plain; charset=us-ascii',
  message = 'Usage limits are exceeded'
}

-- The message that 3scale backend returns in the <reason> field on authorization failure
local backend_reason = 'usage limits are exceeded'

local apicast = require('apicast').new()
local proxy = require 'proxy'

local _M = {
  _VERSION = '3.0.0',
  _NAME = 'APIcast with usage limits error'
}

local mt = { __index = setmetatable(_M, { __index = apicast }) }

function _M.new()
  return setmetatable({}, mt)
end

local utils = require 'threescale_utils'

local function error_limits_exceeded(cached_key)
  ngx.log(ngx.INFO, 'usage limits exceeded for ', cached_key)
  ngx.var.cached_key = nil
  ngx.status = usage_limits_error.status
  ngx.header.content_type = usage_limits_error.content_type
  ngx.print(usage_limits_error.message)
  return ngx.exit(ngx.HTTP_OK)
end

proxy.handle_backend_response = function(self, cached_key, response, ttl)
  ngx.log(ngx.DEBUG, '[backend] response status: ', response.status, ' body: ', response.body)

  local authorized, reason = self.cache_handler(self.cache, cached_key, response, ttl)

  if not authorized then
    local usage_limits_exceeded = utils.match_xml_element(response.body, 'reason', backend_reason)
    if usage_limits_exceeded then
      error_limits_exceeded(cached_key)
    end
  end

  return authorized, reason
end

return _M
