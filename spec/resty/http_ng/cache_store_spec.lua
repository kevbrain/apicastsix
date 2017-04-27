local _M = require 'resty.http_ng.cache_store'

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
    pending('stores response in cache')
  end)
end)
