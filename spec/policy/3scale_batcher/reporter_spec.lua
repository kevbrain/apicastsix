local reporter = require('apicast.policy.3scale_batcher.reporter')
local keys_helper = require('apicast.policy.3scale_batcher.keys_helper')
local ipairs = ipairs
local pairs = pairs
local insert = table.insert

describe('reporter', function()
  local test_service_id = 's1'

  local test_backend_client
  local spy_report_backend_client

  before_each(function()
    test_backend_client = { report = function() return { ok = false } end }
    spy_report_backend_client = spy.on(test_backend_client, 'report')
  end)

  -- Testing using the real ReportsBatcher is a bit difficult because it uses
  -- shared dicts and locks. To simplify we define this table with the same
  -- interface.
  local reports_batcher = {
    reports = {},

    add = function(self, service_id, credentials, usage)
      local deltas = usage.deltas
      for _, metric in ipairs(usage.metrics) do
        local key = keys_helper.key_for_batched_report(service_id, credentials, metric)
        self.reports[key] = (self.reports[key] or 0) + deltas[metric]
      end
    end,

    get_all = function(self, service_id)
      local cached_reports = {}

      for key, value in pairs(self.reports) do
        local report = keys_helper.report_from_key_batched_report(key, value)

        if value and value > 0 and report.service_id == service_id then
          insert(cached_reports, report)
          self.reports[key] = nil
        end
      end

      return cached_reports
    end
  }

  it('returns reports to the batcher when sending reports to backend fails', function()
    local test_reports = {
      { service_id = test_service_id, user_key = 'uk', metric = 'm1', value = 1 }
    }

    reporter.report(test_reports, test_service_id, test_backend_client, reports_batcher)

    assert.same(test_reports, reports_batcher:get_all(test_service_id))
  end)

  it('does not report call report on the backend client when there are no reports', function()
    local no_reports = {}

    reporter.report(no_reports, test_service_id, test_backend_client, reports_batcher)

    assert.spy(spy_report_backend_client).was_not_called()
  end)
end)
