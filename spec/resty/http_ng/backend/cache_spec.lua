local _M = require 'resty.http_ng.backend.cache'
local fake_backend = require 'fake_backend_helper'
local spy = require 'luassert.spy'
local cache_store = require 'resty.http_ng.cache_store'
local http_response = require 'resty.http_ng.response'
local http_request = require 'resty.http_ng.request'
local test_backend_client = require 'resty.http_ng.backend.test'

describe('cache backend', function()
  local test_backend
  before_each(function() test_backend = test_backend_client.new() end)
  after_each(function() test_backend.verify_no_outstanding_expectations() end)

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
      local request = http_request.new{method = 'GET', url = 'http://example.com/test' }
      local backend = _M.new(test_backend, { cache_store = cache_store.new() })

      local headers = {
        ETag = 'etag-value', ['Cache-Control'] = 'max-age=0, private, must-revalidate', Vary = 'Accept-Encoding'
      }
      test_backend.expect{ url = 'http://example.com/test', headers = { via = '1.1 APIcast'} }.respond_with{ status = 200, body = 'ok', headers = headers }
      test_backend.expect{ url = 'http://example.com/test', headers = { if_none_match = 'etag-value', via = '1.1 APIcast' } }
        .respond_with{ status = 304, headers = headers }

      local miss_response = assert(backend:send(request))
      local hit_response = assert(backend:send(request))

      assert.equal('MISS', miss_response.headers.x_cache_status)
      assert.equal('REVALIDATED', hit_response.headers.x_cache_status)

      assert.equal('ok', miss_response.body)
      assert.equal('ok', hit_response.body)
    end)

    it('works with etag and must-revalidate and backend responds something else', function()
      local request = http_request.new{method = 'GET', url = 'http://example.com/test' }
      local backend = _M.new(test_backend, { cache_store = cache_store.new() })

      local headers = {
        ETag = 'etag-value', ['Cache-Control'] = 'max-age=0, private, must-revalidate', Vary = 'Accept-Encoding'
      }
      test_backend.expect{ url = 'http://example.com/test', headers = { via = '1.1 APIcast'} }.respond_with{ status = 200, body = 'ok', headers = headers }
      test_backend.expect{ url = 'http://example.com/test', headers = { if_none_match = 'etag-value', via = '1.1 APIcast' } }
        .respond_with{ status = 200, body = 'foo' }

      local miss_response = assert(backend:send(request))
      local hit_response = assert(backend:send(request))

      assert.equal('MISS', miss_response.headers.x_cache_status)
      assert.equal('MISS', hit_response.headers.x_cache_status)

      assert.equal('ok', miss_response.body)
      assert.equal('foo', hit_response.body)
    end)

    it('works with max-age', function()
      local request = http_request.new{method = 'GET', url = 'http://example.com/test' }
      local backend = _M.new(test_backend, { cache_store = cache_store.new() })

      local headers = {
        ['Cache-Control'] = 'max-age=0, private'
      }
      test_backend.expect{ url = 'http://example.com/test', headers = { via = '1.1 APIcast'} }.respond_with{ status = 200, body = 'ok', headers = headers }
      test_backend.expect{ url = 'http://example.com/test', headers = { via = '1.1 APIcast' } }.respond_with{ status = 200, body = 'foo' }

      local miss_response = assert(backend:send(request))
      local hit_response = assert(backend:send(request))

      assert.equal('MISS', miss_response.headers.x_cache_status)
      assert.equal('MISS', hit_response.headers.x_cache_status)

      assert.equal('ok', miss_response.body)
      assert.equal('foo', hit_response.body)
    end)

    it('accesses caches the call', function()
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
