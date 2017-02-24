local dns_client = require 'resty.resolver.dns_client'

describe('resty.resolver.dns_client', function()
  local dns = dns_client:new{ nameservers = { '127.0.0.1' } }

  describe(':init_resolvers', function()
    it('is called only once', function()
      local s = spy.on(dns_client, 'init_resolvers')
      dns:query('www.3scale.net', { qtype = dns.TYPE_A })
      dns:query('www.3scale.net', { qtype = dns.TYPE_A })
      assert.spy(s).was.called(1)
    end)
  end)

end)
