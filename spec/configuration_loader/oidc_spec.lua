local test_backend_client = require 'resty.http_ng.backend.test'
local loader = require 'apicast.configuration_loader.oidc'
local cjson = require('cjson')

describe('OIDC Configuration loader', function()
  describe('.call', function()
    local test_backend
    before_each(function() test_backend = test_backend_client.new() end)
    before_each(function() loader.discovery.http_client.backend = test_backend end)

    it('ignores empty config', function()
      assert.same({}, { loader.call() })
      assert.same({''}, { loader.call('') })
    end)

    it('ignores config without oidc_issuer_endpoint', function()
      local config = cjson.encode{
        services = {
          { id = 21 },
          { id = 42 },
        }
      }

      assert(loader.call(config))
    end)

    it('forwards all parameters', function()
      assert.same({'{"oidc":[]}', 'one', 'two'}, { loader.call('{}', 'one', 'two')})
    end)

    it('gets openid configuration', function()
      local config = {
        services = {
          { id = 21, proxy = { oidc_issuer_endpoint = 'https://user:pass@example.com' } },
        }
      }

      test_backend
        .expect{ url = "https://example.com/.well-known/openid-configuration" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"jwks_uri":"http://example.com/jwks","issuer":"https://example.com"}]],
        }

      test_backend
        .expect{ url = "http://example.com/jwks" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"keys":[]}]],
        }
      local oidc = loader.call(cjson.encode(config))

      assert.same([[{"services":[{"id":21,"proxy":{"oidc_issuer_endpoint":"https:\/\/user:pass@example.com"}}],"oidc":[{"issuer":"https:\/\/example.com","config":{"jwks_uri":"http:\/\/example.com\/jwks","issuer":"https:\/\/example.com"},"keys":{}}]}]], oidc)
    end)
  end)
end)
