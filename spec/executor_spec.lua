describe('executor', function()
  local phases = {
    'init', 'init_worker',
    'rewrite', 'access', 'balancer',
    'header_filter', 'body_filter',
    'post_action',  'log'
  }

  it('forwards all the policy methods to the policy chain', function()
    local executor = require 'apicast.executor'

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
end)
