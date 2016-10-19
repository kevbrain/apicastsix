local resty_balancer = require 'resty.balancer'

describe('resty.balancer', function()

  describe('.new', function()
    local new = resty_balancer.new

    it('accepts mode', function()
      local b, err = new('round-robin')

      assert.equal('function', type(b.mode))
      assert.falsy(err)
    end)

    it('returns error on invalid mode', function()
      local b, err = new('invalid-mode')

      assert.equal('invalid mode: invalid-mode', err)
      assert.falsy(b)
    end)
  end)

  describe('.modes', function()
    local modes = resty_balancer.modes

    it('returns available modes', function()
      local available_modes = {
        'round-robin'
      }

      assert.same(available_modes, modes())
    end)
  end)

  describe(':peers', function()
    local balancer = resty_balancer.new('round-robin')

    it('returns peers from servers', function()
      local servers = {
        { }
      }

      local peers, err = balancer:peers(servers)

      assert.falsy(err)
      assert.equal(1, #peers)
    end)
  end)

  describe(':set_peer', function()
    local b = resty_balancer.new('round-robin')
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
end)
