local proxy = require 'proxy'
local configuration_store = require 'configuration_store'

describe('Proxy', function()
  before_each(function()
    proxy.configuration:reset()
  end)

  it('has access function', function()
    assert.truthy(proxy.access)
    assert.same('function', type(proxy.access))
  end)

  it('has authorize function', function()
    assert.truthy(proxy.authorize)
    assert.same('function', type(proxy.authorize))
  end)

  it('has post_action function', function()
    assert.truthy(proxy.post_action)
    assert.same('function', type(proxy.post_action))
  end)

  it('finds service by host', function()
    local example = { id = 42, hosts = { 'example.com'} }
    local configuration = configuration_store.new()
    local p = assert(proxy.new(configuration))

    configuration:add(example)

    assert.same(example, p:find_service('example.com'))
    assert.falsy(proxy:find_service('unknown'))
  end)

  describe('.get_upstream', function()
    local get_upstream = proxy.get_upstream

    it('sets correct upstream port', function()
      assert.same(443, get_upstream({ api_backend = 'https://example.com' }).port)
      assert.same(80, get_upstream({ api_backend = 'http://example.com' }).port)
      assert.same(8080, get_upstream({ api_backend = 'http://example.com:8080' }).port)
    end)
  end)

  describe('.configured', function()
    it('returns false when not configured', function()
      local p = assert(proxy.new({configuration = {} }))
      assert.falsy(p:configured())
    end)

    it('returns true when configured', function()
      local configuration = configuration_store.new()
      configuration:add({ id = 42, hosts = { 'example.com' } })
      local p = assert(proxy.new(configuration))

      assert.truthy(p:configured('example.com'))
    end)
  end)

end)
