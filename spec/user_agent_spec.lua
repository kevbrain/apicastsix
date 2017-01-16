local user_agent = require 'user_agent'
local ffi = require("ffi")

describe('3scale', function()
  before_each(function() user_agent.reset() end)

  describe('.deployment', function()
    it('reads from environment', function()
      stub(os, 'getenv').on_call_with('THREESCALE_DEPLOYMENT_ENV').returns('foobar')

      user_agent.reset()

      assert.same('foobar', user_agent.deployment())
    end)

    it('uses internal structure', function()
      user_agent.env.threescale_deployment_env = 'bar'

      assert.same('bar', user_agent.deployment())
    end)
  end)

  describe('.user_agent', function()
    -- User-Agent: <product> / <product-version> <comment>
    -- User-Agent: Mozilla/<version> (<system-information>) <platform> (<platform-details>) <extensions>

    it('matches common format', function()

      user_agent.env.threescale_deployment_env = 'production'

      assert.match('APIcast/' .. user_agent._VERSION, user_agent.call(), nil, true)
    end)

    it('includes system information', function()
      assert.match('(' .. user_agent.system_information() .. ')', user_agent.call())
    end)

    it('includes platform information', function()
      assert.match(' ' .. user_agent.platform(), user_agent.call(), nil, true)
    end)

    it('works as tostring', function()
      assert.equal(user_agent.call(), tostring(user_agent))
    end)

    it('works as function', function()
      assert.equal(user_agent.call(), user_agent())
    end)
  end)


  describe('.system_information', function()
    it('includes os information', function()
      assert.match(ffi.os ..'; ' .. ffi.arch, user_agent.system_information())
    end)

    it('includes deployment information', function()
      user_agent.env.threescale_deployment_env = 'foobar'
      assert.match(' env:foobar', user_agent.system_information())
    end)
  end)

  describe('.platform', function()
    it('includes os information', function()
      local apicast = require('apicast')

      assert.same('APIcast/' .. apicast._VERSION, user_agent.platform())
    end)
  end)

end)
