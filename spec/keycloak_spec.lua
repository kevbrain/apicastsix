local env = require 'resty.env'
local _M = require 'oauth.keycloak'
local test_backend_client = require 'resty.http_ng.backend.test'
local jwt = require 'resty.jwt'

describe('Keycloak', function()
    local test_backend
    local configuration = {
        endpoint = 'http://www.example.com:80/auth/realms/test',
        authorize_url = 'http://www.example.com:80/auth/realms/test/protocol/openid-connect/auth',
        token_url = 'http://www.example.com:80/auth/realms/test/protocol/openid-connect/token',
        public_key = 'foo'
      }

    before_each(function() test_backend = test_backend_client.new() end)
    after_each(function() test_backend.verify_no_outstanding_expectations() end)

  describe('.load_configuration', function()
    it('returns configuration from RHSSO endpoint', function()
      env.set('RHSSO_ENDPOINT', 'http://www.example.com:80/auth/realms/test')

      test_backend.expect{ url = 'http://www.example.com:80/auth/realms/test' }.respond_with{ status = 200, body = '{"public_key":"foo"}'}

      local config = assert(_M.load_configuration(test_backend))

      assert.equals('http://www.example.com:80/auth/realms/test', config.endpoint)
      assert.equals('http://www.example.com:80/auth/realms/test/protocol/openid-connect/auth', config.authorize_url)
      assert.equals('http://www.example.com:80/auth/realms/test/protocol/openid-connect/token', config.token_url)
      assert.equals('-----BEGIN PUBLIC KEY-----\nfoo\n-----END PUBLIC KEY-----', config.public_key)
    end)
  end)

  describe('.new', function()
    it('accepts configuration', function()
        local keycloak = assert(_M.new(configuration))
         assert.equals('http://www.example.com:80/auth/realms/test', keycloak.config.endpoint)
         assert.equals('http://www.example.com:80/auth/realms/test/protocol/openid-connect/auth', keycloak.config.authorize_url)
         assert.equals('http://www.example.com:80/auth/realms/test/protocol/openid-connect/token', keycloak.config.token_url)
         assert.equals('foo', keycloak.config.public_key)
    end)
  end)

  describe('.authorize', function()

    it('connects to keycloak', function()
      local keycloak = assert(_M.new(configuration))

      stub(_M, 'check_credentials', function () return true end)

      ngx.var = { is_args = "?", args = "client_id=foo" }
      stub(ngx.req, 'get_uri_args', function() return { response_type = 'code', client_id = 'foo', redirect_uri = 'bar' } end)

      test_backend.expect{ url = 'http://www.example.com:80/auth/realms/test/protocol/openid-connect/auth?client_id=foo' }
        .respond_with{ status = 200 , body = 'foo', headers = {} }

      stub(_M, 'respond_and_exit')
      keycloak:authorize({}, test_backend)
      assert.spy(_M.respond_and_exit).was.called_with(200, 'foo', {})
    end)

    it('returns error when response_type missing', function()
      local keycloak = _M.new({}, { endpoint = 'http://www.example.com:80/auth/realms/test'})

      stub(_M, 'check_credentials', function () return true end)

      ngx.var = { is_args = "?", args = "" }
      stub(ngx.req, 'get_uri_args', function() return { client_id = 'foo', redirect_uri = 'bar' } end)

      stub(_M, 'respond_with_error')
      keycloak:authorize()
      assert.spy(_M.respond_with_error).was.called_with(400, 'invalid_request')
    end)

    it('returns error when credentials are wrong', function ()
      local keycloak = _M.new({}, { endpoint = 'http://www.example.com:80/auth/reams/test'})

      stub(_M, 'check_credentials', function () return false end)

      stub(ngx.req, 'get_uri_args', function() return { response_type = 'code', client_id = 'foo', redirect_uri = 'bar' } end)

      stub(_M, 'respond_with_error')
      keycloak:authorize()
      assert.spy(_M.respond_with_error).was.called_with(401, 'invalid_client')
    end)
  end)

  describe('.get_token', function()
    it('connects to keycloak', function()
      local keycloak = _M.new(configuration)

      stub(ngx.location, 'capture', function () return { status = 200 } end )

      stub(_M, 'respond_and_exit')
      stub(_M, 'check_credentials', function () return true end)
      ngx.var = { is_args = "?", args = "client_id=foo" }
      stub(ngx.req, 'read_body', function() return { } end)
      stub(ngx.req, 'get_post_args', function() return { grant_type = 'authorization_code', client_id = 'foo', redirect_uri = 'bar', code = 'baz'} end)
      stub(ngx.req, 'get_headers', function() return { } end)

      test_backend.expect{ url = 'http://www.example.com:80/auth/realms/test/protocol/openid-connect/token'}
        .respond_with{ status = 200 , body = 'foo', headers = {} }

      keycloak:get_token({}, test_backend)

      assert.spy(_M.respond_and_exit).was.called_with(200, 'foo', {})
    end)

    it('returns "invalid_request" when grant_type missing', function ()
      local keycloak = _M.new()

      ngx.var = { is_args = "?", args = "client_id=foo" }
      stub(ngx.req, 'read_body', function() return { } end)
      stub(ngx.req, 'get_post_args', function() return { client_id = 'foo', redirect_uri = 'bar', code = 'baz'} end)
      stub(ngx.req, 'get_headers', function() return { } end)

      stub(_M, 'respond_with_error')
      keycloak:get_token()
      assert.spy(_M.respond_with_error).was.called_with(400, 'invalid_request')
    end)

    it('returns "unsupported_grant_type" when grant_type not "recognised"', function ()
      local keycloak = _M.new()

      ngx.var = { is_args = "?", args = "client_id=foo" }
      stub(ngx.req, 'read_body', function() return { } end)
      stub(ngx.req, 'get_post_args', function() return { grant_type = 'foo' } end)
      stub(ngx.req, 'get_headers', function() return { } end)

      stub(_M, 'respond_with_error')
      keycloak:get_token()
      assert.spy(_M.respond_with_error).was.called_with(400, 'unsupported_grant_type')
    end)

    it('returns "invalid_request" when required params not sent', function ()
      local keycloak = _M.new()

      ngx.var = { is_args = "?", args = "client_id=foo" }
      stub(ngx.req, 'read_body', function() return { } end)
      stub(ngx.req, 'get_post_args', function() return { grant_type = 'authorization_code' } end)
      stub(ngx.req, 'get_headers', function() return { } end)

      stub(_M, 'respond_with_error')
      keycloak:get_token()
      assert.spy(_M.respond_with_error).was.called_with(400, 'invalid_request')
    end)

    it('returns "invalid_client" when credentials are wrong', function ()
      local keycloak = _M.new()

      stub(_M, 'check_credentials', function () return false end)

      ngx.var = { is_args = "?", args = "client_id=foo" }
      stub(ngx.req, 'read_body', function() return { } end)
      stub(ngx.req, 'get_post_args', function() return { grant_type = 'authorization_code', client_id = 'foo', redirect_uri = 'bar', code = 'baz'} end)
      stub(ngx.req, 'get_headers', function() return { } end)

      stub(_M, 'respond_with_error')
      keycloak:get_token()
      assert.spy(_M.respond_with_error).was.called_with(401, 'invalid_client')
    end)

    it('accepts client credentials in request body', function()
      local keycloak = _M.new(configuration)
      ngx.var = {}

      stub(ngx.location, 'capture', function () return { status = 200 } end )
      stub(_M, 'respond_and_exit')
      stub(_M, 'check_credentials', function () return true end)
      stub(ngx.req, 'read_body', function() return { } end)
      stub(ngx.req, 'get_post_args', function() return { grant_type = 'client_credentials', client_id = 'foo', client_secret = 'bar'} end)
      stub(ngx.req, 'get_headers', function() return { } end)

      test_backend.expect{ url = 'http://www.example.com:80/auth/realms/test/protocol/openid-connect/token'}
        .respond_with{ status = 200 , body = 'foo', headers = {} }

      keycloak:get_token({}, test_backend)

      assert.spy(_M.respond_and_exit).was.called_with(200, 'foo', {})
    end)

    it('accepts client credentials in Authorization header', function()
      local keycloak = _M.new(configuration)
      local auth = 'Basic Y2xpZW50X2lkOmNsaWVudF9zZWNyZXQ='
      ngx.var = { http_authorization = auth }

      stub(ngx.location, 'capture', function () return { status = 200 } end )

      stub(_M, 'respond_and_exit')
      stub(_M, 'check_credentials', function () return true end)
      stub(ngx.req, 'read_body', function() return { } end)
      stub(ngx.req, 'get_post_args', function() return { grant_type = 'client_credentials' } end)
      stub(ngx.req, 'get_headers', function() return { authorization = auth } end)

      test_backend.expect{
        url = 'http://www.example.com:80/auth/realms/test/protocol/openid-connect/token',
        headers =  { authorization = auth }
      }.respond_with{ status = 200 , body = 'foo', headers = {} }

      keycloak:get_token({}, test_backend)

      assert.spy(_M.respond_and_exit).was.called_with(200, 'foo', {})
    end)

  end)

  describe('.enabled', function()
    it('is falsy if there is no RHSSO_ENDPOINT environment variable set', function()
      assert.is.falsy(_M.enabled())
    end)
    it('is truthy if a non-nil value is set in RHSSO_ENDPOINT environment variable', function()
      env.set('RHSSO_ENDPOINT', 'http://www.example.com:80/auth/realms/test')
      assert.is.truthy(_M.enabled())
    end)
  end)

  describe('.token_get_headers', function()
    it('returns the Authorization header sent in the original request', function()
      local auth = 'Basic Y2xpZW50X2lkOmNsaWVudF9zZWNyZXQ='
      ngx.var = { http_authorization = auth }
      stub(ngx.req, 'get_headers', function() return { authorization = auth } end)

      assert.equals(auth, _M.token_get_headers()['Authorization'])
    end)
    it('returns an empty table if no Authorization header in the request', function()
      ngx.var = { }
      stub(ngx.req, 'get_headers', function() return end)

      assert.are.same({}, _M.token_get_headers())
    end)

    it('does not include any other request headers', function()
      local auth = 'Basic Y2xpZW50X2lkOmNsaWVudF9zZWNyZXQ='
      ngx.var = { http_authorization = auth, http_foo = 'bar' }
      stub(ngx.req, 'get_headers', function() return { authorization = auth, foo = 'bar' } end)

      assert.is.falsy(_M.token_get_headers()['foo'])
    end)

  end)

  describe('.transform_credentials', function()

    it('returns ttl if exp', function()
      local keycloak = _M.new(configuration)
      local jwt_obj = { payload = { aud = "f8c6069e", exp = 1490705281 }, verified = true }

      stub(jwt, 'verify', function() return jwt_obj end)
      stub(ngx, 'now', function() return 1490705200 end)

      local creds, ttl = keycloak:transform_credentials("foo")

      assert.are.same({ app_id = 'f8c6069e' }, creds)
      assert.equals(81, ttl )
    end)

     it('returns nil if no exp', function()
      local keycloak = _M.new(configuration)
      local jwt_obj = { payload = { aud = "f8c6069e" }, verified = true }

      stub(jwt, 'verify', function() return jwt_obj end)
      stub(ngx, 'now', function() return 1490705200 end)

      local creds, ttl = keycloak:transform_credentials("foo")

      assert.are.same({ app_id = 'f8c6069e' }, creds)
      assert.equals(nil, ttl )
    end)
  end)
end)