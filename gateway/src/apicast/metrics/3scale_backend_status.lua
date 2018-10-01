local prometheus = require('apicast.prometheus')
local metrics_updater = require('apicast.metrics.updater')

local format = string.format

local _M = {}

local backend_response_metric = prometheus(
  'counter',
  'threescale_backend_response',
  "Response status codes from 3scale's backend",
  { 'status' }
)

local function label_for_status(status)
  if not status or status == 0 then
    return 'invalid_status'
  else
    return format("%dxx", status/100)
  end
end

function _M.inc(status)
  metrics_updater.inc(backend_response_metric, label_for_status(status))
end

return _M
