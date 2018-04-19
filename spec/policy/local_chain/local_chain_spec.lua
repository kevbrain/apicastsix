local LocalChain = require 'apicast.policy.local_chain'
local policy = require 'apicast.policy'
local PolicyChain = require 'apicast.policy_chain'

describe('local chain', function()
  describe('.rewrite', function()
    -- In all these tests, we export some data in 2 policies of the local
    -- chain, then call rewrite() on the local chain, and finally, check that
    -- each policy has the correct context when it runs its rewrite() method.

    it('forwards a context that includes the data exported by the policies', function()
      local assert_correct_context = function(_, context)
        assert.equals(context.shared_data_1, 'from_policy_1')
        assert.equals(context.shared_data_2, 'from_policy_2' )
      end

      local policy_1 = policy.new()
      policy_1.export = function() return { shared_data_1 = 'from_policy_1' } end
      policy_1.rewrite = assert_correct_context

      local policy_2 = policy.new()
      policy_2.export = function() return { shared_data_2 = 'from_policy_2' } end
      policy_2.rewrite = assert_correct_context

      local policy_chain = PolicyChain.build({ policy_1, policy_2 })

      -- Passing policy_chain in the context. That way the local_chain will use
      -- it instead of building a new one.
      -- Configuration is needed to avoid instantiating a proxy
      local context = { configuration = {}, policy_chain = policy_chain }

      LocalChain.new():rewrite(context)
    end)

    describe('when there are several policies exposing the same data', function()
      it('gives precedence to the first policy in the chain', function()
        local assert_correct_context = function(_, context)
          assert.equals(context.shared_data, 'from_policy_1')
        end

        local policy_1 = policy.new()
        policy_1.export = function() return { shared_data = 'from_policy_1' } end
        policy_1.rewrite = assert_correct_context

        local policy_2 = policy.new()
        policy_2.export = function() return { shared_data = 'from_policy_2' } end
        policy_2.rewrite = assert_correct_context

        local policy_chain = PolicyChain.build({ policy_1, policy_2 })

        local context = { configuration = {}, policy_chain = policy_chain }

        LocalChain.new():rewrite(context)
      end)
    end)

    describe('when the context already includes some data', function()
      it('gives precedence to that data over the one in the local chain', function()
        local assert_correct_context = function(_, context)
          assert.equals(context.shared_data, 'from_context')
        end

        local policy_1 = policy.new()
        policy_1.export = function() return { shared_data = 'from_policy_1' } end
        policy_1.rewrite = assert_correct_context

        local policy_2 = policy.new()
        policy_2.export = function() return { shared_data = 'from_policy_2' } end
        policy_2.rewrite = assert_correct_context

        local policy_chain = PolicyChain.build({ policy_1, policy_2 })

        local context = {
          configuration = {},
          policy_chain = policy_chain,
          shared_data = 'from_context'
        }

        LocalChain.new():rewrite(context)
      end)
    end)
  end)
end)
