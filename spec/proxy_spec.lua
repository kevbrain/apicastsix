local configuration_store = require 'configuration_store'

describe('Proxy', function()
  local configuration, proxy

  before_each(function()
    configuration = configuration_store.new()
    proxy = require('proxy').new(configuration)
  end)

  it('has access function', function()
    assert.truthy(proxy.access)
    assert.same('function', type(proxy.access))
  end)

  it('has authorize function after call', function()
    ngx.var = { backend_endpoint = 'http://localhost:1853' }
    configuration:add({ id = 42, hosts = { 'localhost' }})

    proxy:call('localhost')

    assert.truthy(proxy.authorize)
    assert.same('function', type(proxy.authorize))
  end)

  it('has post_action function', function()
    assert.truthy(proxy.post_action)
    assert.same('function', type(proxy.post_action))
  end)

  it('finds service by host', function()
    local example = { id = 42, hosts = { 'example.com'} }

    configuration:add(example)

    assert.same(example, proxy:find_service('example.com'))
    assert.falsy(proxy:find_service('unknown'))
  end)

  it('does not return old configuration when new one is available', function()
    local foo = { id = '42', hosts = { 'foo.example.com'} }
    local bar = { id = '42', hosts = { 'bar.example.com'} }

    configuration:add(foo, -1) -- expired record
    assert.equal(foo, proxy:find_service('foo.example.com'))

    configuration:add(bar, -1) -- expired record
    assert.equal(bar, proxy:find_service('bar.example.com'))
    assert.falsy(proxy:find_service('foo.example.com'))
  end)

  describe('.get_upstream', function()
    local get_upstream = proxy.get_upstream

    it('sets correct upstream port', function()
      assert.same(443, get_upstream({ api_backend = 'https://example.com' }).port)
      assert.same(80, get_upstream({ api_backend = 'http://example.com' }).port)
      assert.same(8080, get_upstream({ api_backend = 'http://example.com:8080' }).port)
    end)
  end)
end)
