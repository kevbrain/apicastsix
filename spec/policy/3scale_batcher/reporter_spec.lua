local reporter = require('apicast.policy.3scale_batcher.reporter')
local ReportsBatcher = require('apicast.policy.3scale_batcher.reports_batcher')
local lrucache = require('resty.lrucache')
local resty_lock = require 'resty.lock'
local pairs = pairs
local insert = table.insert

-- ReportsBatcher uses a shdict. For the test we can use a lrucache instead
-- but we need to define 2 missing methods (safe_add and get_keys)
local function build_fake_shdict()
  local fake_shdict = lrucache.new(100)

  fake_shdict.safe_add = function(self, k, v)
    local current = self:get(k) or 0
    self:set(k, current + v)
  end

  fake_shdict.get_keys = function(self)
    local res = {}

    for k, _ in pairs(self.hasht) do
      insert(res, k)
    end

    return res
  end

  return fake_shdict
end

describe('reporter', function()
  local test_service_id = 's1'

  local test_backend_client
  local spy_report_backend_client

  before_each(function()
    test_backend_client = { report = function() return { ok = false } end }
    spy_report_backend_client = spy.on(test_backend_client, 'report')

    -- Mock the lock so it can always be acquired and returned without waiting.
    stub(resty_lock, 'new').returns(
      { lock = function() return 0 end, unlock = function() return 1 end }
    )
  end)

  local reports_batcher = ReportsBatcher.new(build_fake_shdict())

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
