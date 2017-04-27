local _M = require 'resty.http_ng.backend.cache'
local fake_backend = require 'fake_backend_helper'
local spy = require 'luassert.spy'
local http_response = require 'resty.http_ng.response'
local cache_store = require 'resty.http_ng.cache_store'

local inspect = require 'inspect'
describe('cache backend', function()
  describe('GET method', function()
    local function cache(res, options)
      local fake = fake_backend.new(res)
      return _M.new(fake, options)
    end

    it('accesses the url', function()
      local res = spy.new(function(req) return http_response.new(req, 200, { }, 'ok') end)

      local response, err = cache(res):send{method = 'GET', url = 'http://example.com/' }

      assert.falsy(err)
      assert.truthy(response)

      assert.spy(res).was.called(1)

      assert.equal('ok', response.body)
    end)

    it('accesses caches the call', function()
      local res = spy.new(function(req)
        return http_response.new(req, 200, {
          cache_control = 'private, max-age=10'
        }, 'ok')
      end)

      local backend = cache(res, { cache_store = cache_store.new() })

      local function check()
        local response, err = backend:send{method = 'GET', url = 'http://example.com/' }

        assert.spy(res).was.called(1)

        assert.truthy(response)
        assert.falsy(err)

        assert.equal('ok', response.body)
      end

      check()
      check()
    end)
  end)
end)
