local _M = require 'configuration_loader.remote_v2'
local test_backend_client = require 'resty.http_ng.backend.test'
local cjson = require 'cjson'
local user_agent = require 'user_agent'

describe('Configuration Rmote Loader V2', function()

  local test_backend
  local loader

  before_each(function() test_backend = test_backend_client.new() end)
  before_each(function()
    loader = _M.new('http://example.com', { client = test_backend })
  end)

  after_each(function() test_backend.verify_no_outstanding_expectations() end)

  describe('http_client #http', function()
    it('has correct user agent', function()
      test_backend.expect{ url = 'http://example.com/t', headers = { ['User-Agent'] = tostring(user_agent) } }
        .respond_with{ status = 200  }

      local res, err = loader.http_client.get('http://example.com/t')

      assert.falsy(err)
      assert.equal(200, res.status)
    end)
  end)

  describe(':services', function()
    it('retuns list of services', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json' }.
        respond_with{ status = 200, body = cjson.encode({ services = {
            { service = { id = 1 }},
            { service = { id = 2 }}
          }})
        }

      local services = loader:services()

      assert.truthy(services)
      assert.equal(2, #services)
    end)
  end)

  describe(':config', function()
    it('loads a configuration', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services/42/proxy/configs/sandbox/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 13,
              environment = 'sandbox',
              content = { id = 42, backend_version = 1 }
            }
          }
        ) }
      local service = { id = 42 }

      local config = loader:config(service, 'sandbox', 'latest')

      assert.truthy(config)
      assert.equal('table', type(config.content))
      assert.equal(13, config.version)
      assert.equal('sandbox', config.environment)
    end)
  end)

  describe(':call', function()
    it('returns configuration for all services', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json' }.
        respond_with{ status = 200, body = cjson.encode({ services = {
            { service = { id = 1 }},
            { service = { id = 2 }}
          }})
        }
      test_backend.expect{ url = 'http://example.com/admin/api/services/1/proxy/configs/staging/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 13,
              environment = 'staging',
              content = { id = 1, backend_version = 1 }
            }
          }
        )}
      test_backend.expect{ url = 'http://example.com/admin/api/services/2/proxy/configs/staging/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 42,
              environment = 'staging',
              content = { id = 2, backend_version = 2 }
            }
          }
        )}

      local config = assert(loader:call('staging'))

      assert.truthy(config)
      assert.equals('string', type(config))

      assert.equals(2, #(cjson.decode(config).services))
    end)

    it('does not crash on error when getting services', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json' }.
        respond_with{ status = 404 }

      local config, err = loader:call('staging')

      assert.falsy(config)
      assert.equal('invalid status', err)
    end)

    it('returns configuration even when some services are missing', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json' }.
        respond_with{ status = 200, body = cjson.encode({ services = {
            { service = { id = 1 }},
            { service = { id = 2 }}
          }})
        }
      test_backend.expect{ url = 'http://example.com/admin/api/services/1/proxy/configs/staging/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 13,
              environment = 'staging',
              content = { id = 1, backend_version = 1 }
            }
          }
        )}
      test_backend.expect{ url = 'http://example.com/admin/api/services/2/proxy/configs/staging/latest.json' }.
        respond_with{ status = 404 }

      local config = assert(loader:call('staging'))

      assert.truthy(config)
      assert.equals('string', type(config))

      assert.equals(1, #(cjson.decode(config).services))
    end)
  end)

  describe('.call', function()
    it('gets environment from ENV', function()
      local _, err = loader.call()
      assert.equal('missing environment', err)
    end)
  end)
end)
