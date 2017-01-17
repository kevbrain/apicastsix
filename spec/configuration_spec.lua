local configuration = require 'configuration'
local cjson = require 'cjson'
local env = require 'resty.env'

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

  describe('.encode', function()
    it('encodes to json by default', function()
      local t = { a = 1, b = 2 }
      assert.same('{"a":1,"b":2}', configuration.encode(t))
    end)

    it('does not do double encoding', function()
      local str = '{"a":1,"b":2}'
      assert.same(str, configuration.encode(str))
    end)

    it('encodes nil to null', function()
      assert.same('null', configuration.encode(nil))
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
      env.set('APICAST_SERVICES', '42,21')

      local services = services_limit()

      assert.same({ [42] = true, [21] = true }, services)
    end)

    it('reads from environment', function()
      env.set('APICAST_SERVICES', '')

      local services = services_limit()

      assert.same({}, services)
    end)
  end)

end)
