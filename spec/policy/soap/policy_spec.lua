local Usage = require('apicast.usage')

describe('policy', function()
  describe('.rewrite', function()
    local context -- Context shared between policies

    -- Define a config with 2 rules. One increases hits by 10 and the other by
    -- 20. Their patterns have values that allow us to easily associate them
    -- with a SOAP action receive via SOAPAction header or via Content-Type.
    local policy_config = {
      mapping_rules = {
        {
          pattern = '/soap_action$',
          metric_system_name = 'hits',
          delta = 10
        },
        {
          pattern = '/soap_action_ctype$',
          metric_system_name = 'hits',
          delta = 20
        }
      }
    }

    local soap_policy = require('apicast.policy.soap').new(policy_config)

    before_each(function()
      -- Initialize a shared context with a usage of hits = 1.
      context = { usage = Usage.new() }
      context.usage:add('hits', 1)
    end)

    describe('when the SOAP action is in the SOAPAction header', function()
      it('calculates the usage and merges it with the one in the context', function()
        ngx.req.get_headers = function()
          return { SOAPAction = '/soap_action' }
        end

        soap_policy:rewrite(context)

        assert.equals(11, context.usage.deltas['hits'])
      end)
    end)

    describe('when the SOAP action is in the Content-Type header', function()
      describe('and it is the only param', function()
        it('calculates the usage and merges it with the one in the context', function()
          local header_val = "application/soap+xml;action=/soap_action_ctype"

          ngx.req.get_headers = function()
            return { ["Content-Type"] = header_val }
          end

          soap_policy:rewrite(context)

          assert.equals(21, context.usage.deltas['hits'])
        end)
      end)

      describe('and there are other params', function()
        it('calculates the usage and merges it with the one in the context', function()
          local header_val = "application/soap+xml;a_param=x;" ..
              "action=/soap_action_ctype;another_param=y"

          ngx.req.get_headers = function()
            return { ["Content-Type"] = header_val }
          end

          soap_policy:rewrite(context)

          assert.equals(21, context.usage.deltas['hits'])
        end)
      end)
    end)

    describe('when the SOAP action is in the SOAPAction and the Content-Type headers', function()
      it('calculates the usage and merges it with the one in the context', function()
        ngx.req.get_headers = function()
          return {
            SOAPAction = '/soap_action',
            ["Content-Type"] = "application/soap+xml;action=/soap_action_ctype"
          }
        end

        soap_policy:rewrite(context)

        assert.equals(21, context.usage.deltas['hits'])
      end)
    end)

    describe('when the SOAP action is not specified', function()
      it('it does not modify the usage received in the context', function()
        ngx.req.get_headers = function() return {} end

        soap_policy:rewrite(context)

        assert.equals(1, context.usage.deltas['hits'])
      end)
    end)
  end)
end)
