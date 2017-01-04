local provider = require 'provider'

describe('Provider', function()
  before_each(function()
    ngx.ctx.configuration = {}
  end)

  teardown(function()
    ngx.ctx.configuration = nil
  end)

  it('has access function', function()
    assert.truthy(provider.access)
    assert.same('function', type(provider.access))
  end)

  it('has authorize function', function()
    assert.truthy(provider.authorize)
    assert.same('function', type(provider.authorize))
  end)

  it('has post_action function', function()
    assert.truthy(provider.post_action)
    assert.same('function', type(provider.post_action))
  end)

  it('finds service by host', function()
    local example = { id = 42, hosts = { 'example.com'} }

    provider.configuration:add(example)

    assert.same(example, provider.find_service('example.com'))
    assert.falsy(provider.find_service('unknown'))
  end)

  describe('.get_upstream', function()
    local get_upstream = provider.get_upstream

    it('sets correct upstream port', function()
      assert.same(443, get_upstream({ api_backend = 'https://example.com' }).port)
      assert.same(80, get_upstream({ api_backend = 'http://example.com' }).port)
      assert.same(8080, get_upstream({ api_backend = 'http://example.com:8080' }).port)
    end)
  end)

end)
