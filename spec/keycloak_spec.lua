local _M = require 'oauth.keycloak'
local test_backend_client = require 'resty.http_ng.backend.test'

describe('Keycloak', function()
    local test_backend
    before_each(function() test_backend = test_backend_client.new() end)
    after_each(function() test_backend.verify_no_outstanding_expectations() end)
    

  describe('.new', function()
    it('accepts configuration', function()
        local keycloak = assert(_M.new({ public_key = 'foobar' }))

        assert.equals('-----BEGIN PUBLIC KEY-----\nfoobar\n-----END PUBLIC KEY-----', keycloak.config.public_key)
    end)
  end)

  describe('.authorize', function()

    it('connects to keycloak', function()
        local keycloak = _M.new{ server = 'http://example.com', realm = 'foobar', client = test_backend }

        ngx.var = { is_args = "?", args = "client_id=foo" }
        stub(ngx.req, 'get_uri_args', function() return { response_type = 'code', client_id = 'foo', redirect_uri = 'bar'} end)


        test_backend.expect{ url = 'http://example.com/auth/realms/foobar/protocol/openid-connect/auth?client_id=foo' }
          .respond_with{ status = 200 , body = 'foo', headers = {} }

        stub(_M, 'respond_and_exit')
        keycloak:authorize()
        assert.spy(_M.respond_and_exit).was.called_with(200, 'foo', {})
    end)
  end)

  describe('.get_token', function()

    it('')
  end)
end)