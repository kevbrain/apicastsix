--- Transaction
-- A transaction contains the information that APIcast needs to send to the
-- 3scale backend in order to know whether a call should be authorized.

local setmetatable = setmetatable

local _M = {}

local mt = { __index = _M }

function _M.new(service_id, credentials, usage)
  local self = setmetatable({}, mt)

  self.service_id = service_id
  self.credentials = credentials
  self.usage = usage

  return self
end

return _M
