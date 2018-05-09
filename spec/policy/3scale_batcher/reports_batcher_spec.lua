local ReportsBatcher = require 'apicast.policy.3scale_batcher.reports_batcher'
local Usage = require 'apicast.usage'
local keys_helper = require 'apicast.policy.3scale_batcher.keys_helper'
local resty_lock = require 'resty.lock'

describe('reports batcher', function()
  describe('.add', function()
    before_each(function()
      -- Stub locks. Not relevant for these tests.
      stub(resty_lock, 'new').returns({
        lock = function() return true end,
        unlock = function() return true end
      })
    end)

    local service_id = 's1'
    local credentials = { user_key = 'uk' }

    local usage = Usage.new()
    local metric = 'm1'
    usage:add(metric, 1)

    local report_key = keys_helper.key_for_batched_report(service_id, credentials, metric)

    -- Note: all these tests use a mocked instance of ngx.shared.dict.
    -- 'safe_add()' returns 'no memory' when the dict ran out of memory and
    -- 'exists' when the key already exists in the dict.

    describe('when a report cannot be batched because the dict ran out of mem', function()
      it('does not try to increase the value of the batched report', function()
        local test_dict = {
          safe_add = function(_, _, _) return nil, 'no memory' end,
          incr = function(_, _, _) end
        }
        local spy_incr_dict = spy.on(test_dict, 'incr')
        local reports_batcher = ReportsBatcher.new(test_dict, 'batched_reports_locks')

        reports_batcher:add(service_id, credentials, usage)

        assert.spy(spy_incr_dict).was_not_called()
      end)
    end)

    describe('when a report already exists in the dict', function()
      it('increases its usage', function()
        local test_dict = {
          safe_add = function(_, _, _) return nil, 'exists' end,
          incr = function(_, _, _) end
        }
        local spy_incr_dict = spy.on(test_dict, 'incr')
        local reports_batcher = ReportsBatcher.new(test_dict, 'batched_reports_locks')

        reports_batcher:add(service_id, credentials, usage)

        assert.spy(spy_incr_dict).was_called_with(test_dict, report_key, 1)
      end)
    end)

    describe('when a report is not in the dict', function()
      it('adds it with the given usage', function()
        local test_dict = {
          safe_add = function(_, _, _) return true end,
          incr = function(_, _, _) end
        }
        local spy_add_dict = spy.on(test_dict, 'safe_add')
        local spy_incr_dict = spy.on(test_dict, 'incr')
        local reports_batcher = ReportsBatcher.new(test_dict, 'batched_reports_locks')

        reports_batcher:add(service_id, credentials, usage)

        assert.spy(spy_add_dict).was_called.with(test_dict, report_key, 1)
        assert.spy(spy_incr_dict).was_not_called()
      end)
    end)
  end)
end)
