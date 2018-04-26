local ReportsBatch = require('apicast.policy.3scale_batcher.reports_batch')
local Usage = require('apicast.usage')

local pairs = pairs

local _M = {}

local function return_reports(service_id, batch, reports_batcher)
  local credentials_type = batch.credentials_type

  for credential, metrics in pairs(batch.reports) do
    local usage = Usage.new()
    for metric, value in pairs(metrics) do
      usage:add(metric, value)
    end

    reports_batcher:add(
      service_id,
      { [credentials_type] = credential },
      usage
    )
  end
end

function _M.report(reports, service_id, backend_client, reports_batcher)
  if #reports > 0 then
    local batch = ReportsBatch.new(service_id, reports)

    local res_report = backend_client:report(batch)

    if not res_report.ok then
      ngx.log(ngx.WARN, "Returning reports to the batcher because couldn't report to backend")
      return_reports(service_id, batch, reports_batcher)
    end
  end
end

return _M
