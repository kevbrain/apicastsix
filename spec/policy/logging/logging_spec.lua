local LoggingPolicy = require('apicast.policy.logging')

describe('Logging policy', function()
  describe('.log', function()
    before_each(function()
      ngx.var = {}
    end)

    context('when access logs are enabled', function()
      it('sets ngx.var.access_logs_enabled to "1"', function()
        local logging = LoggingPolicy.new({ enable_access_logs = true })

        logging:log()

        assert.equals('1', ngx.var.access_logs_enabled)
      end)
    end)

    context('when access logs are disabled', function()
      it('sets ngx.var.enable_access_logs to "0"', function()
        local logging = LoggingPolicy.new({ enable_access_logs = false })

        logging:log()

        assert.equals('0', ngx.var.access_logs_enabled)
      end)
    end)

    context('when access logs are not configured', function()
      it('enables them by default by setting ngx.var.enable_access_logs to "1"', function()
        local logging = LoggingPolicy.new({})

        logging:log()

        assert.equals('1', ngx.var.access_logs_enabled)
      end)
    end)
  end)
end)
