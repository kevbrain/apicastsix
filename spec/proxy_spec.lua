local http_ng_response = require('resty.http_ng.response')
local lrucache = require('resty.lrucache')

local configuration_store = require 'apicast.configuration_store'
local Service = require 'apicast.configuration.service'
local Usage = require 'apicast.usage'
local test_backend_client = require 'resty.http_ng.backend.test'

describe('Proxy', function()
  local configuration, proxy, test_backend

  before_each(function()
    configuration = configuration_store.new()
    proxy = require('apicast.proxy').new(configuration)
    test_backend = test_backend_client.new()
    proxy.http_ng_backend = test_backend
  end)

  it('has access function', function()
    assert.truthy(proxy.access)
    assert.same('function', type(proxy.access))
  end)

  describe(':rewrite', function()
    local service
    before_each(function()
      -- Replace original ngx.header. Openresty does not allow to modify it when
      -- running busted tests.
      ngx.header = {}

      ngx.var = { backend_endpoint = 'http://localhost:1853', uri = '/a/uri' }
      stub(ngx.req, 'get_method', function () return 'GET' end)
      service = Service.new({ extract_usage = function() end })
    end)

    it('works with part of the credentials', function()
      service.credentials = { location = 'headers' }
      service.backend_version = 2
      ngx.var.http_app_key = 'key'
      assert.falsy(proxy:rewrite(service))
    end)
  end)

  it('has post_action function', function()
    assert.truthy(proxy.post_action)
    assert.same('function', type(proxy.post_action))
  end)

  describe('.get_upstream', function()
    local get_upstream
    before_each(function() get_upstream = proxy.get_upstream end)

    it('sets correct upstream port', function()
      assert.same(443, get_upstream({ api_backend = 'https://example.com' }):port())
      assert.same(80, get_upstream({ api_backend = 'http://example.com' }):port())
      assert.same(8080, get_upstream({ api_backend = 'http://example.com:8080' }):port())
    end)
  end)

  describe('.authorize', function()
    local service = { backend_authentication = { value = 'not_baz' }, backend = { endpoint = 'http://0.0.0.0' } }

    it('takes ttl value if sent', function()
      local ttl = 80
      ngx.var = { cached_key = 'client_id=blah', http_x_3scale_debug='baz', real_url='blah' }

      local response = { status = 200 }
      stub(test_backend, 'send', function() return response end)

      stub(proxy, 'cache_handler').returns(true)

      local usage = Usage.new()
      usage:add('foo', 0)
      proxy:authorize(service, usage, { client_id = 'blah' }, ttl)

      assert.spy(proxy.cache_handler).was.called_with(
        proxy.cache, 'client_id=blah:usage%5Bfoo%5D=0', response, ttl)
    end)

    it('works with no ttl', function()
      ngx.var = { cached_key = "client_id=blah", http_x_3scale_debug='baz', real_url='blah' }

      local response = { status = 200 }
      stub(test_backend, 'send', function() return response end)
      stub(proxy, 'cache_handler').returns(true)

      local usage = Usage.new()
      usage:add('foo', 0)
      proxy:authorize(service, usage, { client_id = 'blah' })

      assert.spy(proxy.cache_handler).was.called_with(
        proxy.cache, 'client_id=blah:usage%5Bfoo%5D=0', response, nil)
    end)
  end)

  describe('.handle_backend_response', function()
    it('returns a rejection reason when given', function()
      local authorized, rejection_reason = proxy:handle_backend_response(
        lrucache.new(1),
        http_ng_response.new(nil, 403, { ['3scale-rejection-reason'] = 'some_reason' }, ''),
        nil)

      assert.falsy(authorized)
      assert.equal('some_reason', rejection_reason)
    end)
  end)
end)
