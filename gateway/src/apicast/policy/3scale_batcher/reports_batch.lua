local setmetatable = setmetatable
local ipairs = ipairs

local _M = {}

local mt = { __index = _M }

local function add_value(reports, credential, metric, value)
  reports[credential] = reports[credential] or {}
  reports[credential][metric] = reports[credential][metric] or 0
  reports[credential][metric] = reports[credential][metric] + value
end

function _M.new(service_id, reports)
  local self = setmetatable({}, mt)

  self.service_id = service_id

  if reports[1] then
    -- A service only works with a type of credentials. We know that all the
    -- reports will have the same type so checking the first one is enough.
    self.credentials_type = (reports[1].user_key and 'user_key') or
                            (reports[1].app_id and 'app_id') or
                            (reports[1].access_token and 'access_token')
  end

  self.reports = {}
  for _, report in ipairs(reports) do
    add_value(self.reports, report[self.credentials_type], report.metric, report.value)
  end

  return self
end

return _M
