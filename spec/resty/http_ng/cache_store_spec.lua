local _M = require 'resty.http_ng.cache_store'
local http_response = require 'resty.http_ng.response'
local http_request = require 'resty.http_ng.request'
local spy = require 'luassert.spy'

describe('HTTP cache store', function()

  describe('.new', function()
    local cache_store = _M.new()

    assert.truthy(cache_store.get)
    assert.truthy(cache_store.set)
  end)

  describe(':get', function()
    pending('fetches response from cache')
  end)

  describe(':set', function()

    describe('max-age=100', function()
      it('stores response in cache', function()
        local store = {}
        local cache = _M.new(store)
        local request = http_request.new({ method = 'GET', url = 'http://example.com/api/foo.json' })
        local response = http_response.new(request, 200, { vary = 'Accept-Encoding', cache_control = 'max-age=100'  }, '<content>')

        store.set = spy.new(function(self, cache_key, res)
          assert.equal(store, self)
          assert.equal('GET:http://example.com/api/foo.json', cache_key)
          assert.same(cache.entry(response), res)
        end)

        assert(cache:set(response))
        assert.spy(store.set).was.called(1)
      end)
    end)

    describe('max-age=0', function()
      it('stores response in cache', function()
        local store = {}
        local cache = _M.new(store)
        local request = http_request.new({ method = 'GET', url = 'http://example.com/api/foo.json' })
        local response = http_response.new(request, 200, { vary = 'Accept-Encoding', cache_control = 'max-age=0'  }, '<content>')

        store.set = spy.new(function() end)

        assert(cache:set(response))
        assert.spy(store.set).was.called(1)
      end)
    end)

    describe('Cache-Control: no-store', function()
      it('not stores responses in cache', function()
        local store = { set = spy.new(function() end) }
        local cache = _M.new(store)
        local request = http_request.new({ method = 'GET', url = 'http://example.com/api/foo.json' })
        local response = http_response.new(request, 200, { vary = 'Accept-Encoding', cache_control = 'no-store, max-age=100'  }, '<content>')

        assert.falsy(cache:set(response))
        assert.spy(store.set).was_not.called()
      end)
    end)
  end)
end)
