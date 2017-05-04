local _M = require 'resty.http_ng.backend.cache'
local fake_backend = require 'fake_backend_helper'
local spy = require 'luassert.spy'
local cache_store = require 'resty.http_ng.cache_store'
local http_response = require 'resty.http_ng.response'
local http_request = require 'resty.http_ng.request'

local inspect = require 'inspect'

describe('cache backend', function()
  describe('GET method', function()
    local function cache(res, options)
      local fake = fake_backend.new(res)
      return _M.new(fake, options or { cache_store = cache_store.new() })
    end

    it('accesses the url', function()
      local res = spy.new(function(req) return http_response.new(req, 200, { }, 'ok') end)
      local request = http_request.new{method = 'GET', url = 'http://example.com/' }
      local response, err = cache(res):send(request)

      assert.falsy(err)
      assert.truthy(response)

      assert.spy(res).was.called(1)

      assert.equal('ok', response.body)
      assert.equal('MISS', response.headers.x_cache_status)
    end)

    it('works with etag and must-revalidate', function()
      local res = spy.new(function(req)
        local headers = {
          ETag = 'etag-value', ['Cache-Control'] = 'max-age=0, private, must-revalidate', Vary = 'Accept-Encoding'
        }
        assert.equal('1.1 APIcast', tostring(req.headers.via))
        if req.headers.if_none_match == 'etag-value' then
          return http_response.new(req, 304, headers, '')
        else
          return http_response.new(req, 200, headers, 'ok')
        end
      end)
      local request = http_request.new{method = 'GET', url = 'http://example.com/test' }
      local backend = cache(res)

      local miss_response = assert(backend:send(request))
      local hit_response = assert(backend:send(request))

      assert.spy(res).was.called(2)

      assert.equal('MISS', miss_response.headers.x_cache_status)
      assert.equal('REVALIDATED', hit_response.headers.x_cache_status)

      assert.equal('ok', miss_response.body)
      assert.equal('ok', hit_response.body)
    end)

    it('accesses caches the call #TEST', function()
      local server = spy.new(function(req)
        assert.match('1.1 APIcast', req.headers.via)
        return http_response.new(req, 200, {
          cache_control = 'private, max-age=10'
        }, 'ok')
      end)

      local backend = cache(server)

      local request = http_request.new{method = 'GET', url = 'http://example.com/' }

      local function response(req)
        local res, err = backend:send(req)

        assert.spy(server).was.called(1)

        assert.truthy(res)
        assert.falsy(err)

        assert.equal('ok', res.body)

        return res
      end

      local miss = response(request)
      local hit = response(request)

      assert.equal('MISS', miss.headers.x_cache_status)
      assert.equal('HIT', hit.headers.x_cache_status)
      assert.equal(0, hit.headers.age)
    end)
  end)
end)
