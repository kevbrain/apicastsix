local resty_resolver = require 'resty.resolver'

describe('resty.resolver', function()

  -- TODO: consider :new(self) self api like resty.dns.resolver
  describe('.new', function()
    local new = resty_resolver.new

    it('accepts dns', function()
      local dns = { 'dns resolver' }
      local r = new(dns)

      assert.equal(dns, r.dns)
    end)
  end)

  describe(':get_servers', function()
    local dns = { }
    local resolver = resty_resolver.new(dns)

    it('returns servers', function()
      dns.query = spy.new(function()
        return {
          { name = '3scale.net' , address = '127.0.0.1' }
        }
      end)

      local servers, err = resolver:get_servers('3scale.net')

      assert.falsy(err)
      assert.equal(1, #servers)
      assert.spy(dns.query).was.called_with(dns, '3scale.net')
    end)

    it('accepts port', function()
      dns.query = function() return { {address = '127.0.0.2'} } end

      local servers, err = resolver:get_servers('localhost', { port = 1337 })
      local server, _ = unpack(servers or {})

      assert.falsy(err)
      assert.truthy(server)
      assert.equal(1337, server.port)
      assert.equal('127.0.0.2', server.address)
    end)
  end)

end)
