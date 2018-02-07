local mapping_rules_matcher = require('apicast.mapping_rules_matcher')

describe('mapping_rules_matcher', function()
  local func_true = function() return true end
  local func_false = function() return false end

  -- Test rules. Instead of instantiating mapping rules, we just mock the
  -- methods and attributes we are interested in, for simplicity.
  local rule_1 = { matches = func_true, system_name = 'hits', delta = 1 }
  local rule_2 = { matches = func_false, system_name = 'hits', delta = 2 }
  local rule_3 = { matches = func_true, system_name = 'hits', delta = 3 }
  local rules = { rule_1, rule_2, rule_3 }

  describe('.get_usage_from_matches', function()
    local usage, matched_rules = mapping_rules_matcher.get_usage_from_matches(
      'GET', '/', {}, rules)

    it('returns the usage from matching the mapping rules', function()
      assert.same({ hits = 4 }, usage.deltas)
    end)

    it('returns the rules that matched', function()
      assert.same({ rule_1, rule_3 } , matched_rules)
    end)
  end)

  describe('.matches', function()
    describe('when there is a match', function()
      local not_maching_rule = { matches = func_false }
      local matching_rule = { matches = func_true }

      it('returns true and the index of the first rule that matches', function()
        local matches, index = mapping_rules_matcher.matches(
          'GET', '/', {}, { not_maching_rule, matching_rule })

        assert.is_true(matches)
        assert.equals(2, index)
      end)
    end)

    describe('when there is not a match', function()
      local not_matching_rule = { matches = func_false }

      it('returns false', function()
        local matches = mapping_rules_matcher.matches(
          'GET', '/', {}, { not_matching_rule })

        assert.is_false(matches)
      end)
    end)
  end)
end)
