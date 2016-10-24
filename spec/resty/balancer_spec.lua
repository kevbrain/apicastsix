local resty_balancer = require 'resty.balancer'
local round_robin = require 'resty.balancer.round_robin'

describe('resty.balancer', function()

  describe('.new', function()
    local new = resty_balancer.new

    it('accepts mode', function()
      local b, err = new(function() end)

      assert.equal('function', type(b.mode))
      assert.falsy(err)
    end)

    it('returns error on invalid mode', function()
      local b, err = new()

      assert.equal('missing balancing function', err)
      assert.falsy(b)
    end)
  end)

  describe(':peers', function()
    local balancer = resty_balancer.new(function() end)

    it('returns peers from servers', function()
      local servers = {
        { address = '127.0.0.2' }
      }

      local peers, err = balancer:peers(servers, 80)

      assert.falsy(err)
      assert.equal(1, #peers)
    end)
  end)

  describe(':set_peer', function()
    local b = resty_balancer.new(function(peers) return peers[1] end)
    b.balancer = { }

    it('returns peers from servers', function()
      local peers = {
        { '127.0.0.2', 8091 }
      }
      b.balancer.set_current_peer = spy.new(function() return true end)

      local ok, err = b:set_peer(peers)

      assert.falsy(err)
      assert.truthy(ok)
      assert.spy(b.balancer.set_current_peer).was.called_with('127.0.0.2', 8091)
    end)
  end)

  describe('round-robin balancer', function()
    local balancer = round_robin.new()

    balancer.balancer = {
      set_current_peer = function() return true end
    }

    local servers = {
      { address = '127.0.0.1', port = 80 },
      { address = '127.0.0.2', port = 8080 },
      { address = '127.0.0.3', port = 8090 },
      query = 'example.com'
    }

    local peers = balancer:peers(servers)
    peers.cur = 1

    it('loops through peers', function()
      local first = balancer:set_peer(peers)
      local second = balancer:set_peer(peers)
      local third = balancer:set_peer(peers)

      assert.same({
        { '127.0.0.1', 80 },
        { '127.0.0.2', 8080 },
        { '127.0.0.3', 8090 }
      }, { first, second, third})
    end)
  end)
end)
