local executor = require 'apicast.executor'
local policy_chain = require 'apicast.policy_chain'
local Policy = require 'apicast.policy'

describe('executor', function()
  local phases = {
    'init', 'init_worker',
    'rewrite', 'access', 'balancer',
    'header_filter', 'body_filter',
    'post_action',  'log'
  }

  it('forwards all the policy methods to the policy chain', function()
    -- Policies included by default in the executor
    local default_executor_chain = {
      require 'apicast.policy.load_configuration',
      require 'apicast.policy.find_service',
      require 'apicast.policy.local_chain'
    }

    -- Stub all the nginx phases methods for each of the policies
    for _, phase in ipairs(phases) do
      for _, policy in ipairs(default_executor_chain) do
        stub(policy, phase)
      end
    end

    -- For each one of the nginx phases, verify that when called on the
    -- executor, each one of the policies executes the code for that phase.
    for _, phase in ipairs(phases) do
      executor[phase](executor)
      for _, policy in ipairs(default_executor_chain) do
        assert.stub(policy[phase]).was_called()
      end
    end
  end)

  it('freezes the policy chain', function()
    local chain = policy_chain.new({})
    assert.falsy(chain.frozen)

    executor.new(chain)
    assert.truthy(chain.frozen)
  end)

  describe('.context', function()
    it('returns what the policies of the chain export', function()
      local policy_1 = Policy.new('1')
      policy_1.export = function() return { p1 = '1'} end

      local policy_2 = Policy.new('2')
      policy_2.export = function() return { p2 = '2' } end

      local chain = policy_chain.new({ policy_1, policy_2 })
      local context = executor.new(chain):context('rewrite')

      assert.equal('1', context.p1)
      assert.equal('2', context.p2)
    end)

    it('works with policy chains that contain other chains', function()
      local policy_1 = Policy.new('1')
      policy_1.export = function() return { p1 = '1'} end

      local policy_2 = Policy.new('2')
      policy_2.export = function() return { p2 = '2' } end

      local policy_3 = Policy.new('3')
      policy_3.export = function() return { p3 = '3' } end

      local inner_chain = policy_chain.new({ policy_2, policy_3 })
      local outer_chain = policy_chain.new({ policy_1, inner_chain })

      local context = executor.new(outer_chain):context('rewrite')

      assert.equal('1', context.p1)
      assert.equal('2', context.p2)
      assert.equal('3', context.p3)
    end)
  end)
end)
