local _M = require 'resty.resolver.http'

describe('resty.resolver.http', function()

  describe('.new', function()
    it('initializes client', function()
      local client = _M.new()

      assert.truthy(client)
    end)
  end)

  describe(':connect', function()
    it('resolves localhost', function()
      local client = _M.new()
      client:set_timeout(1000)
      client.resolver.cache:save({ { address = '127.0.0.1', name = 'unknown.', ttl = 1800 } })
      assert(client:connect('unknown', 1984))
      assert.equal('unknown', client.host)
      assert.equal(1984, client.port)
    end)
  end)

end)
