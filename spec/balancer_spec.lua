local apicast_balancer = require 'apicast.balancer'
local resty_balancer = require 'resty.balancer'

describe('apicast.balancer', function()

  describe('.call', function()
    local b = resty_balancer.new(function(peers) return peers[1] end)
    b.balancer = { }

    ngx.var = {
      proxy_host = 'upstream'
    }

    it('sets default port from scheme if no port is specified for peers', function()
      b.peers = function() return { { '127.0.0.2' } } end
      ngx.var.proxy_pass = 'https://example.com'

      b.balancer.set_current_peer = spy.new(function() return true end)
      apicast_balancer:call({},b)
      assert.spy(b.balancer.set_current_peer).was.called_with('127.0.0.2', 443)
    end)
  end)
end)
