local dns_resolver = require 'resty.resolver.dns'

describe('resty.resolver.dns', function()
  local dns = dns_resolver:new{ nameservers = { '127.0.0.1' } }

  describe(':init_resolvers', function()
    it('is called only once', function()
      local s = spy.on(dns_resolver, 'init_resolvers')
      dns:query('www.3scale.net', { qtype = dns.TYPE_A })
      dns:query('www.3scale.net', { qtype = dns.TYPE_A })
      assert.spy(s).was.called(1)
    end)
  end)

end)
