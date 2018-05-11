local balancer = require('apicast.balancer')
local UpstreamPolicy = require('apicast.policy.upstream')

describe('Upstream policy', function()
  -- Set request URI and matched/non-matched upstream used in all the tests
  local test_req_uri = 'http://example.com/'
  local test_upstream_matched_host = 'localhost'
  local test_upstream_matched = string.format("http://%s/a_path:8080",
    test_upstream_matched_host)
  local test_upstream_matched_proxy_pass = 'http://upstream/a_path:8080'
  local test_upstream_not_matched = 'http://localhost/a_path:80'

  local test_upstream_matched_url = {
    host = 'localhost',
    path = '/a_path:8080',
    scheme = 'http'
  }

  local context -- Context shared between policies

  before_each(function()
    context = {}
    ngx.var = { uri = test_req_uri }
  end)

  describe('.rewrite', function()
    describe('when there is a rule that matches the request URI', function()
      local config_with_a_matching_rule = {
        rules = {
          { regex = '/i_dont_match', url = test_upstream_not_matched },
          { regex = '/', url = test_upstream_matched }
        }
      }

      local upstream = UpstreamPolicy.new(config_with_a_matching_rule)

      it('stores in the context the URL of that rule', function()
        upstream:rewrite(context)
        assert.same(test_upstream_matched_url, context.new_upstream)
      end)
    end)

    describe('when there are several rules that match the request URI', function()
      local config_with_several_matching_rules = {
        rules = {
          { regex = '/i_dont_match', url = test_upstream_not_matched },
          { regex = '/', url = test_upstream_matched },
          { regex = '/', url = 'some_upstream_that_will_not_be_used' }
        }
      }

      local upstream = UpstreamPolicy.new(config_with_several_matching_rules)

      it('stores in the context the URL of the 1st rule that matches', function()
        upstream:rewrite(context)
        assert.same(test_upstream_matched_url, context.new_upstream)
      end)
    end)

    describe('when there are no rules that match the request URI', function()
      local config_without_matching_rules = {
        rules = {
          { regex = '/i_dont_match', url = test_upstream_not_matched }
        }
      }

      local upstream = UpstreamPolicy.new(config_without_matching_rules)

      it('does not store a URL in the context', function()
        upstream:rewrite(context)
        assert.is_nil(context.new_upstream)
      end)
    end)
  end)

  describe('.content', function()
    before_each(function()
      -- Set headers_sent to false, otherwise, the upstream is not changed
      ngx.headers_sent = false

      stub(ngx.req, 'set_header')
      stub(ngx, 'exec')
    end)

    describe('when there is a new upstream in the context', function()
      before_each(function()
        context.new_upstream = test_upstream_matched_url
      end)

      it('changes the upstream', function()
        local upstream = UpstreamPolicy.new({})

        upstream:content(context)

        assert.equals(test_upstream_matched_proxy_pass, ngx.var.proxy_pass)
        assert.stub(ngx.req.set_header).was_called_with('Host',
          test_upstream_matched_host)
        assert.stub(ngx.exec).was_called_with('@upstream')
      end)

      it('marks in the context that the upstream has changed', function()
        local upstream = UpstreamPolicy.new({})
        upstream:content(context)
        assert.is_truthy(context.upstream_changed)
      end)
    end)

    describe('when there is not a new upstream in the context', function()
      before_each(function()
        context.new_upstream = nil
      end)

      it('does not change the upstream', function()
        local upstream = UpstreamPolicy.new({})
        upstream:content(context)

        assert.is_nil(ngx.var.proxy_pass)
        assert.stub(ngx.req.set_header).was_not_called()
        assert.stub(ngx.exec).was_not_called()
      end)

      it('does not mark in the context that the upstream has changed', function()
        local upstream = UpstreamPolicy.new({})
        upstream:content(context)
        assert.is_falsy(context.upstream_changed)
      end)
    end)
  end)

  describe('.balancer', function()
    describe('when the upstream has been changed in previous phases', function()
      it('calls the balancer', function()
        stub(balancer, 'call')
        local upstream = UpstreamPolicy.new()

        upstream:balancer({ upstream_changed = true })

        assert.stub(balancer.call).was_called()
      end)
    end)

    describe('when the upstream has not been changed in previous phases', function()
      it('does not call the balancer', function()
        stub(balancer, 'call')
        local upstream = UpstreamPolicy.new()

        for _, val in ipairs({ false, nil }) do
          upstream:balancer({ upstream_changed = val })

          assert.stub(balancer.call).was_not_called()
        end
      end)
    end)
  end)
end)
