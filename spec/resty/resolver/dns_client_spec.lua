local dns_client = require 'resty.resolver.dns_client'

describe('resty.resolver.dns_client', function()

  describe(':init_resolvers #network', function()
    it('is called only once', function()
      local dns = dns_client:new{ nameservers = { '127.0.0.1' } }
      local s = spy.on(dns, 'init_resolvers')

      dns:query('www.3scale.net', { qtype = dns.TYPE_A })
      dns:query('www.3scale.net', { qtype = dns.TYPE_A })

      assert.spy(s).was.called(1)
    end)

    it('handles invalid resolvers', function()
      local nameservers = {
        'invalid',
        '256.0.0.0',
        '127.0.0.1',
      }
      local dns = dns_client:new{nameservers = nameservers }
      local resolvers = assert(dns:init_resolvers())

      assert.equal(1, #resolvers)
    end)
  end)

end)
