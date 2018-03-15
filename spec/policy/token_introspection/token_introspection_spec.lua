local TokenIntrospection = require('apicast.policy.token_introspection')

local test_backend_client = require('resty.http_ng.backend.test')
local cjson = require('cjson')
describe("token introspection policy", function()
  describe("execute introspection", function()
    local context
    local test_backend
    local test_access_token = "test"
    local test_client_id = "client"
    local test_client_secret = "secret"
    local test_basic_auth = 'Basic '..ngx.encode_base64(test_client_id..':'..test_client_secret)

    local function assert_authentication_failed()
      assert.same(ngx.status, 403)
      assert.stub(ngx.say).was.called_with("auth failed")
      assert.stub(ngx.exit).was.called_with(403)
    end

    before_each(function()
      test_backend = test_backend_client.new()
      ngx.var = {}
      ngx.var.http_authorization = "Bearer "..test_access_token
      context = {
        service = {
          auth_failed_status = 403,
          error_auth_failed = "auth failed"
        }
      }
    end)

    it('success with valid token', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        introspection_url = introspection_url,
        client_id = test_client_id,
        client_secret = test_client_secret
      }

      test_backend
        .expect{
          url = introspection_url,
          method = 'POST',
          body = 'token='..test_access_token..'&token_type_hint=access_token',
          headers = {
            ['Authorization'] = test_basic_auth
          }
        }
        .respond_with{
          status = 200,
          body = cjson.encode({
              active = true
          })
        }
      local token_policy = TokenIntrospection.new(policy_config)
      token_policy.http_client.backend = test_backend
      token_policy:access(context)
    end)

    it('failed with invalid token', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        introspection_url = introspection_url,
        client_id = "client",
        client_secret = "secret"
      }

      test_backend
        .expect{
          url = introspection_url,
          method = 'POST',
          body = 'token='..test_access_token..'&token_type_hint=access_token',
          headers = {
            ['Authorization'] = test_basic_auth
          }
        }
        .respond_with{
          status = 200,
          body = cjson.encode({
              active = false
          })
        }
      stub(ngx, 'say')
      stub(ngx, 'exit')

      local token_policy = TokenIntrospection.new(policy_config)
      token_policy.http_client.backend = test_backend
      token_policy:access(context)
      assert_authentication_failed()
    end)

    it('failed with bad status code', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        introspection_url = introspection_url,
        client_id = "client",
        client_secret = "secret"
      }

      test_backend
        .expect{
          url = introspection_url,
          method = 'POST',
          body = 'token='..test_access_token..'&token_type_hint=access_token',
          headers = {
            ['Authorization'] = test_basic_auth
          }
        }
        .respond_with{
          status = 404,
        }
      stub(ngx, 'say')
      stub(ngx, 'exit')

      local token_policy = TokenIntrospection.new(policy_config)
      token_policy.http_client.backend = test_backend
      token_policy:access(context)
      assert_authentication_failed()
    end)

    it('failed with null response', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        introspection_url = introspection_url,
        client_id = "client",
        client_secret = "secret"
      }

      test_backend
        .expect{
          url = introspection_url,
          method = 'POST',
          body = 'token='..test_access_token..'&token_type_hint=access_token',
          headers = {
            ['Authorization'] = test_basic_auth
          }
        }
        .respond_with{
          status = 200,
          body = 'null'
        }
      stub(ngx, 'say')
      stub(ngx, 'exit')

      local token_policy = TokenIntrospection.new(policy_config)
      token_policy.http_client.backend = test_backend
      token_policy:access(context)
      assert_authentication_failed()
    end)

    it('failed with bad contents type', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        introspection_url = introspection_url,
        client_id = "client",
        client_secret = "secret"
      }

      test_backend
        .expect{
          url = introspection_url,
          method = 'POST',
          body = 'token='..test_access_token..'&token_type_hint=access_token',
          headers = {
            ['Authorization'] = test_basic_auth
          }
        }
        .respond_with{
          status = 200,
          body = "<html></html>"
        }
      stub(ngx, 'say')
      stub(ngx, 'exit')

      local token_policy = TokenIntrospection.new(policy_config)
      token_policy.http_client.backend = test_backend
      token_policy:access(context)
      assert_authentication_failed()
    end)

    after_each(function()
      test_backend.verify_no_outstanding_expectations()
    end)
  end)
end)

