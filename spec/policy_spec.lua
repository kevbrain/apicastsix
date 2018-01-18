local policy = require 'apicast.policy'

describe('policy', function()
  local phases = {
    'init', 'init_worker',
    'rewrite', 'access',
    'content', 'balancer',
    'header_filter', 'body_filter',
    'post_action',  'log'
  }

  describe('.new', function()
    it('allows to set a name for the policy', function()
      local my_policy_name = 'custom_mapping_rules'
      local my_policy = policy.new(my_policy_name)

      assert.equals(my_policy_name, my_policy._NAME)
    end)

    it('allows to set a version for the policy', function()
      local my_policy_version = '2.0'
      local my_policy = policy.new('my_policy', my_policy_version)

      assert.equals(my_policy_version, my_policy._VERSION)
    end)

    it('set the version to 0.0 when not specified', function()
      local my_policy = policy.new('my_policy')
      assert.equals('0.0', my_policy._VERSION)
    end)

    it('defines a method for each of the nginx phases; they do nothing by default', function()
      local my_policy = policy.new('custom_authorizer')

      for _, phase in policy.phases() do
        -- To be precise, we should check that the function is defined, returns
        -- nil, and it does not have any side-effects. Checking the latter is
        -- complicated so we'll leave it for now.
        assert.not_nil(my_policy[phase])
        assert.is_nil(my_policy[phase]())
      end
    end)

    it('allows to set a custom function for each nginx phase', function()
      local my_policy = policy.new('custom_authorizer')
      my_policy.access = function() return 'custom_access_ran' end

      assert.equals('custom_access_ran', my_policy.access())
    end)
  end)

  describe('.phases', function()
    it('returns the nginx phases where policies can run, sorted by order of execution', function()
      local res = {}
      for _, phase in policy.phases() do
        table.insert(res, phase)
      end

      assert.same(phases, res)
    end)
  end)
end)
