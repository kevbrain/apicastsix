local UpstreamSelector = require('apicast.policy.routing.upstream_selector')
local Operation = require('apicast.conditions.operation')
local Condition = require('apicast.conditions.condition')

describe('UpstreamSelector', function()
  local true_condition = Condition.new(
    { Operation.new('1', 'plain', '==', '1', 'plain') },
    'and'
  )

  local false_condition = Condition.new(
    { Operation.new('1', 'plain', '!=', '1', 'plain') },
    'and'
  )

  describe('.select', function()
    describe('when there is only one rule', function()
      it('returns its upstream if the condition is true', function()
        local rules = {
          {
            url = 'http://example.com',
            condition = true_condition
          }
        }

        local upstream_selector = UpstreamSelector.new()
        local upstream = upstream_selector:select(rules, {})

        assert.equals('http', upstream.uri.scheme)
        assert.equals('example.com', upstream.uri.host)
      end)

      it('returns nil if the condition is false', function()
        local rules = {
          {
            url = 'http://example.com',
            condition = false_condition
          }
        }

        local upstream_selector = UpstreamSelector.new()
        local upstream = upstream_selector:select(rules, {})

        assert.is_nil(upstream)
      end)
    end)

    describe('when there are several rules', function()
      it('returns the upstream of the first rule that matches', function()
        local rules = {
          {
            url = 'http://example.com',
            condition = true_condition
          },
          {
            url = 'http://localhost',
            condition = true_condition
          }
        }

        local upstream_selector = UpstreamSelector.new()
        local upstream = upstream_selector:select(rules, {})

        assert.equals('http', upstream.uri.scheme)
        assert.equals('example.com', upstream.uri.host)
      end)

      it('returns nil if none of them match', function()
        local rules = {
          {
            url = 'http://example.com',
            condition = false_condition
          },
          {
            url = 'http://localhost',
            condition = false_condition
          }
        }

        local upstream_selector = UpstreamSelector.new()
        local upstream = upstream_selector:select(rules, {})

        assert.is_nil(upstream)
      end)
    end)

    describe('when there are no rules', function()
      it('returns nil', function()
        local upstream_selector = UpstreamSelector.new()
        local upstream = upstream_selector:select({}, {})

        assert.is_nil(upstream)
      end)
    end)

    describe('when rules is nil', function()
      it('returns nil', function()
        local upstream_selector = UpstreamSelector.new()
        local upstream = upstream_selector:select(nil, {})

        assert.is_nil(upstream)
      end)
    end)

    describe('when a rule that matches has a host for the Host header', function()
      describe('and it is not empty', function()
        it('sets the host for the header', function()
          local rule = {
            url = 'http://example.com',
            condition = true_condition,
            host_header = 'some_host.com'
          }

          local upstream_selector = UpstreamSelector.new()
          local upstream = upstream_selector:select({ rule }, {})

          assert.equals(rule.host_header, upstream.host)
        end)
      end)

      describe('and it is empty', function()
        it('does not set the host for the header', function()
          local rule = {
            url = 'http://example.com',
            condition = true_condition,
            host_header = ''
          }

          local upstream_selector = UpstreamSelector.new()
          local upstream = upstream_selector:select({ rule }, {})

          assert.is_nil(upstream.host)
        end)
      end)
    end)
  end)
end)
