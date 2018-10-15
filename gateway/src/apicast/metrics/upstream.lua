local tonumber = tonumber

local prometheus = require('apicast.prometheus')

local _M = {}

local upstream_status_codes = prometheus(
  'counter',
  'upstream_status',
  'HTTP status from upstream servers',
  { 'status' }
)

local upstream_resp_times = prometheus(
  'histogram',
  'upstream_response_time_seconds',
  'Response times from upstream servers'
)

local function inc_status_codes_counter(status)
  if tonumber(status) and upstream_status_codes then
    upstream_status_codes:inc(1, { status })
  end
end

local function add_resp_time(response_time)
  local time = tonumber(response_time)

  if time and upstream_resp_times then
    upstream_resp_times:observe(time)
  end
end

function _M.report(status, response_time)
  inc_status_codes_counter(status)
  add_resp_time(response_time)
end

return _M
