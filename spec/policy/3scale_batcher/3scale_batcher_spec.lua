local ThreescaleBatcher = require('apicast.policy.3scale_batcher')
local AuthsCache = require('apicast.policy.3scale_batcher.auths_cache')
local Transaction = require('apicast.policy.3scale_batcher.transaction')
local Usage = require('apicast.usage')
local configuration = require('apicast.configuration')
local lrucache = require('resty.lrucache')

describe('3scale batcher policy', function()
  describe('.new', function()
    it('allows to configure the batching period', function()
      local test_batching_period = 3
      local config = { batch_report_seconds = test_batching_period }
      local batcher_policy = ThreescaleBatcher.new(config)

      assert.equals(test_batching_period, batcher_policy.batch_reports_seconds)
    end)

    it('assigns a default of 10s for the batching period', function()
      local batcher_policy = ThreescaleBatcher.new({})

      assert.equals(10, batcher_policy.batch_reports_seconds)
    end)
  end)

  describe('.access', function()
    local service = configuration.parse_service({ id = 42 })
    local service_id = service.id
    local credentials = { user_key = 'uk' }
    local usage = Usage.new()
    usage:add('m1', 1)
    local transaction = Transaction.new(service_id, credentials, usage)

    local context
    local batcher_policy

    before_each(function()
      ngx.var = {}
      ngx.header = {}
      ngx.print = function() end

      batcher_policy = ThreescaleBatcher.new({})
      batcher_policy.auths_cache = AuthsCache.new(lrucache.new(10), 10)
      stub(batcher_policy.reports_batcher, 'add')

      context = {
        service = service,
        usage = usage,
        credentials = credentials
      }
    end)

    describe('when the request is cached', function()
      describe('and it is authorized', function()
        it('adds the report to the batcher', function()
          batcher_policy.auths_cache:set(transaction, 200)

          batcher_policy:access(context)

          assert.stub(batcher_policy.reports_batcher.add).was_called_with(
            batcher_policy.reports_batcher, transaction)
        end)
      end)

      describe('and it is not authorized', function()
        it('does not add the report to the batcher', function()
          batcher_policy.auths_cache:set(transaction, 409, 'limits_exceeded')

          batcher_policy:access(context)

          assert.stub(batcher_policy.reports_batcher.add).was_not_called()
        end)

        it('returns an error', function()
          batcher_policy.auths_cache:set(transaction, 409, 'limits_exceeded')

          batcher_policy:access(context)

          assert.is_true(ngx.status >= 400 and ngx.status < 500)
        end)
      end)
    end)
  end)
end)
