local ThreescaleReferrer = require('apicast.policy.3scale_referrer')

local ConfigurationStore = require 'apicast.configuration_store'
local Proxy = require 'apicast.proxy'

describe('3scale referrer policy', function()
  describe('.rewrite', function()
    describe('when the "Referer" header is set', function()
      local referrer = '3scale.net'
      setup(function() ngx.var = { http_referer = referrer } end)

      it('stores in the proxy of the context the referrer', function()
        local context = { proxy = Proxy.new(ConfigurationStore.new()) }
        local policy = ThreescaleReferrer.new()

        policy:rewrite(context)

        assert.equals(referrer, context.proxy.extra_params_backend_authrep.referrer)
      end)
    end)

    describe('when the "Referer" header is not set', function()
      setup(function() ngx.var = { http_referer = nil } end)

      it('does not store anything in the proxy', function()
        local context = { proxy = Proxy.new(ConfigurationStore.new()) }
        local policy = ThreescaleReferrer.new()

        policy:rewrite(context)

        assert.is_nil(context.proxy.extra_params_backend_authrep.referrer)
      end)
    end)
  end)
end)
