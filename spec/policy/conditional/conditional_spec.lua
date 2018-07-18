local ConditionalPolicy = require('apicast.policy.conditional')
local Policy = require('apicast.policy')
local PolicyChain = require('apicast.policy_chain')
local Engine = require('apicast.policy.conditional.engine')

describe('Conditional policy', function()
  local test_policy_chain
  local context
  local condition = "request_path == '/some_path'"

  before_each(function()
    test_policy_chain = PolicyChain.build({})

    for _, phase in Policy.phases() do
      test_policy_chain[phase] = spy.new(function() end)
    end

    context = {}
  end)

  describe('when the condition is true', function()
    before_each(function()
      stub(Engine, 'evaluate').returns(true)
    end)

    it('forwards the policy phases (except init and init_worker) to the chain', function()
      local conditional = ConditionalPolicy.new({ condition = condition })

      -- .new() will try to load the chain, set it here to avoid that and
      -- control which one to use.
      conditional.policy_chain = test_policy_chain

      for _, phase in Policy.phases() do
        if phase ~= 'init' and phase ~= 'init_worker' then
          conditional[phase](conditional, context)

          assert.spy(test_policy_chain[phase]).was_called(1)
          assert.spy(test_policy_chain[phase]).was_called_with(
            test_policy_chain,
            context
          )
        end
      end
    end)
  end)

  describe('when the condition is false', function()
    before_each(function()
      stub(Engine, 'evaluate').returns(false)
    end)

    it('does not forward the policy phases to the chain', function()
      local conditional = ConditionalPolicy.new({ condition = condition })
      conditional.policy_chain = test_policy_chain

      for _, phase in Policy.phases() do
        conditional[phase](conditional, context)

        assert.spy(test_policy_chain[phase]).was_not_called()
      end
    end)
  end)

  describe('.export', function()
    it('forwards the method to the policy chain', function()
      local exported_by_chain = { a = 1, b = 2 }

      stub(test_policy_chain, 'export').returns(exported_by_chain)

      local conditional = ConditionalPolicy.new({ condition = condition })
      conditional.policy_chain = test_policy_chain

      assert.same(exported_by_chain, conditional:export())
    end)
  end)
end)
