local config_file = assert(io.open('fixtures/config.json')):read('*a')

local configuration = require 'configuration'

local cjson = require 'cjson'

describe('Configuration object', function()
  describe('.parse', function()
    it('returns new configuration object', function()
      assert.same(configuration.new({}), configuration.parse('{}', cjson))
    end)

    it('works with table', function()
      assert.same(configuration.new({}), configuration.parse({}))
    end)
  end)

  describe('provides information from the config file', function()
    local config = configuration.new({services = { 'a' }})

    it('returns services', function()
      assert.truthy(config.services)
      assert.equals(1, #config.services)
    end)
  end)

  describe('.download', function()
    it('returns error on missing endpoint', function()
      assert.same({nil, 'missing endpoint'}, { configuration.download() })
    end)

    it('returns error on invalid URI', function()
      assert.same({nil, 'invalid endpoint'}, { configuration.download('foobar') })
    end)

    it('returns error on invalid URI', function()
      assert.same({nil, 'connection refused'}, { configuration.download('http://127.0.0.1:1234/config/') })
    end)
  end)

  it('.download', function()
    configuration.download('http://user:pass@localhost:3000')
    configuration.download('https://user@localhost')
    configuration.download('http://:pass@lvh.me:3000')
  end)

  describe('.read', function()
    it('ignores empty path', function()
      assert.same({nil, 'missing path'}, { configuration.read() })
      assert.same({nil, 'missing path'}, { configuration.read('') })
    end)
  end)

  describe('.parse_service', function()
    it('ignores empty hostname_rewrite', function()
      local config = configuration.parse_service({ proxy = { hostname_rewrite = '' }})

      assert.same(false, config.hostname_rewrite)
    end)

    it('populates hostname_rewrite', function()
      local config = configuration.parse_service({ proxy = { hostname_rewrite = 'example.com' }})

      assert.same('example.com', config.hostname_rewrite)
    end)
  end)

  describe('.decode', function()
    it('ignores empty string', function()
      assert.same(nil, configuration.decode(''))
    end)
  end)

  describe('.url', function()
    it('works with port', function()
      assert.same({'https', false, false, 'example.com', '8443'}, configuration.url('https://example.com:8443'))
    end)

    it('works with user', function()
      assert.same({'https', 'user', false, 'example.com', false }, configuration.url('https://user@example.com'))
    end)

    it('works with user and password', function()
      assert.same({'https', 'user', 'password', 'example.com', false }, configuration.url('https://user:password@example.com'))
    end)

    it('works with port and path', function()
      assert.same({'http', false, false, 'example.com', '8080', '/path'}, configuration.url('http://example.com:8080/path'))
    end)
  end)

  describe('.filter_services', function()
    local filter_services = configuration.filter_services

    it('works with nil', function()
      local services = { { id = 42 } }
      assert.equal(services, filter_services(services))
    end)

    it('works with table with ids', function()
      local services = { { id = 42 } }

      assert.same(services, filter_services(services, { 42 }))
      assert.same({}, filter_services(services, { 21 }))
    end)
  end)

  insulate('.services_limit', function()
    local services_limit = configuration.services_limit

    it('reads from environment', function()
      stub(os, 'getenv').on_call_with('APICAST_SERVICES').returns('42,21')

      local services = services_limit()

      assert.same({ [42] = true, [21] = true }, services)
    end)

    it('reads from environment', function()
      stub(os, 'getenv').on_call_with('APICAST_SERVICES').returns('')

      local services = services_limit()

      assert.same({}, services)
    end)
  end)

end)
