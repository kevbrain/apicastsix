local _M = require 'resty.resolver.socket'

describe('resty.resolver.socket', function()

  describe('.new', function()
    it('initializes client', function()
      local wrapper = _M.new(ngx.socket.tcp())

      assert.truthy(wrapper)
    end)
  end)

  describe(':connect', function()
    it('resolves localhost', function()
      local sock = ngx.socket.tcp()
      sock:settimeout(1000)
      local wrapper = _M.new(sock)

      wrapper.resolver.cache:save({ { address = '127.0.0.1', name = 'unknown.', ttl = 1800 } })
      assert(wrapper:connect('unknown', 1984))
      assert.equal('unknown', wrapper.host)
      assert.equal(1984, wrapper.port)
    end)
  end)

end)
