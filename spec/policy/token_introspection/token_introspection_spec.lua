local test_backend_client = require('resty.http_ng.backend.test')
local cjson = require('cjson')
describe("token introspection policy", function()
  describe("execute introspection", function()
    local context
    local test_backend

    before_each(function()
      test_backend = test_backend_client.new()
      ngx.var = {}
      ngx.var.http_authorization = "Bearer test"
      context = {
        service = {
          auth_failed_status = 403,
          error_auth_failed = "auth failed"
        }
      }
    end)

    it('execute token introspection success', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        client = test_backend,
        introspection_url = introspection_url,
        client_id = "client",
        client_secret = "secret"
      }

      test_backend.expect{ url = introspection_url }.
        respond_with{
          status = 200,
          body = cjson.encode({
              active = true
          })
        }
      local token_policy = require('apicast.policy.token_introspection').new(policy_config)
      token_policy:access(context)

      test_backend.verify_no_outstanding_expectations()
    end)

    it('execute token introspection failed', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        client = test_backend,
        introspection_url = introspection_url,
        client_id = "client",
        client_secret = "secret"
      }

      test_backend.expect{ url = introspection_url }.
        respond_with{
          status = 200,
          body = cjson.encode({
              active = false
          })
        }
      stub(ngx, 'say')
      stub(ngx, 'exit')

      local token_policy = require('apicast.policy.token_introspection').new(policy_config)
      token_policy:access(context)
      assert.same(ngx.status, 403)
      assert.stub(ngx.say).was.called_with("auth failed")
      assert.stub(ngx.exit).was.called_with(403)
      test_backend.verify_no_outstanding_expectations()
    end)

    it('execute token introspection request failed', function()
      local introspection_url = "http://example/token/introspection"
      local policy_config = {
        client = test_backend,
        introspection_url = introspection_url,
        client_id = "client",
        client_secret = "secret"
      }

      test_backend.expect{ url = introspection_url }.
        respond_with{
          status = 404,
        }
      stub(ngx, 'say')
      stub(ngx, 'exit')

      local token_policy = require('apicast.policy.token_introspection').new(policy_config)
      token_policy:access(context)
      assert.same(ngx.status, 403)
      assert.stub(ngx.say).was.called_with("auth failed")
      assert.stub(ngx.exit).was.called_with(403)
      test_backend.verify_no_outstanding_expectations()
    end)
  end)
end)

