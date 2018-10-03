local prometheus = require('apicast.prometheus')

local format = string.format

local _M = {}

local threescale_backend_call = prometheus(
  'counter',
  'threescale_backend_calls',
  "Calls to the 3scale backend",
  { 'endpoint', 'status' }
)

local function label_for_status(status)
  if not status or status == '' or status == 0 then
    return 'invalid_status'
  else
    return format("%dxx", status/100)
  end
end

function _M.report(endpoint, status)
  if threescale_backend_call then
    threescale_backend_call:inc(1, { endpoint, label_for_status(status) })
  end
end

return _M
