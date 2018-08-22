local apicast_balancer = require('apicast.balancer')
local UpstreamPolicy = require('apicast.policy.upstream')
local Upstream = require('apicast.upstream')

describe('Upstream policy', function()
  -- Set request URI and matched/non-matched upstream used in all the tests
  local test_req_uri = 'http://example.com/'
  local test_upstream_matched_host = 'localhost'
  local test_upstream_matched = string.format("http://%s/a_path:8080",
    test_upstream_matched_host)
  local test_upstream_not_matched = 'http://localhost/a_path:80'

  local test_upstream_matched_url = {
    uri = {
      host = 'localhost',
      path = '/a_path:8080',
      scheme = 'http',
    }
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

      local policy = UpstreamPolicy.new(config_with_a_matching_rule)

      it('stores in the context the URL of that rule', function()
        policy:rewrite(context)
        assert.contains(test_upstream_matched_url, context[policy])
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

      local policy = UpstreamPolicy.new(config_with_several_matching_rules)

      it('stores in the context the URL of the 1st rule that matches', function()
        policy:rewrite(context)
        assert.contains(test_upstream_matched_url, context[policy])
      end)
    end)

    describe('when there are no rules that match the request URI', function()
      local config_without_matching_rules = {
        rules = {
          { regex = '/i_dont_match', url = test_upstream_not_matched }
        }
      }

      local policy = UpstreamPolicy.new(config_without_matching_rules)

      it('does not store a URL in the context', function()
        policy:rewrite(context)
        assert.is_nil(context[policy])
      end)
    end)
  end)

  describe('.content', function()
    describe('when there is a new upstream in the context', function()
      it('changes the upstream', function()
        local upstream = Upstream.new(test_upstream_matched)
        local policy = UpstreamPolicy.new({})

        stub.new(upstream, 'rewrite_request')
        stub.new(upstream, 'call')

        local ctx = { [policy] = upstream }
        policy:content(ctx)

        assert.spy(upstream.call).was_called_with(upstream, ctx)
      end)
    end)

    describe('when there is not a new upstream in the context', function()
      it('does not change the upstream', function()
        local policy = UpstreamPolicy.new({})
        assert.returns_error('no upstream', policy:content(context))
      end)
    end)
  end)

  describe('.balancer', function()
    it('delegates to apicast balancer', function()
      local policy = UpstreamPolicy.new()

      assert.equal(apicast_balancer.call, policy.balancer)
    end)
  end)
end)
