local Condition = require('apicast.conditions.condition')
local Operation = require('apicast.conditions.operation')

describe('Engine', function()
  describe('.new', function()
    it('raises error with an unsupported operation', function()
      local res, err = pcall(Condition.new, {}, '<>')

      assert.is_falsy(res)
      assert.is_truthy(err)
    end)
  end)

  describe('.evaluate', function()
    it('combines operations with "and"', function()
      local true_condition = Condition.new(
        {
          Operation.new('1', 'plain', '==', '1', 'plain'),
          Operation.new('2', 'plain', '==', '2', 'plain'),
          Operation.new('3', 'plain', '==', '3', 'plain')
        },
        'and'
      )

      assert.is_true(true_condition:evaluate())

      local false_condition = Condition.new(
        {
          Operation.new('1', 'plain', '==', '1', 'plain'),
          Operation.new('2', 'plain', '==', '20', 'plain'),
          Operation.new('3', 'plain', '==', '3', 'plain')
        },
        'and'
      )

      assert.is_false(false_condition:evaluate())
    end)

    it('combines operations with "or"', function()
      local true_condition = Condition.new(
        {
          Operation.new('1', 'plain', '==', '10', 'plain'),
          Operation.new('2', 'plain', '==', '20', 'plain'),
          Operation.new('3', 'plain', '==', '3', 'plain')
        },
        'or'
      )

      assert.is_true(true_condition:evaluate())

      local false_condition = Condition.new(
        {
          Operation.new('1', 'plain', '==', '10', 'plain'),
          Operation.new('2', 'plain', '==', '20', 'plain'),
          Operation.new('3', 'plain', '==', '30', 'plain')
        },
        'or'
      )

      assert.is_false(false_condition:evaluate())
    end)

    it('combines operations with "and" by default', function()
      local true_condition = Condition.new(
        {
          Operation.new('1', 'plain', '==', '1', 'plain'),
          Operation.new('2', 'plain', '==', '2', 'plain'),
          Operation.new('3', 'plain', '==', '3', 'plain')
        }
      )

      assert.is_true(true_condition:evaluate())

      local false_condition = Condition.new(
        {
          Operation.new('1', 'plain', '==', '1', 'plain'),
          Operation.new('2', 'plain', '==', '20', 'plain'),
          Operation.new('3', 'plain', '==', '3', 'plain')
        }
      )

      assert.is_false(false_condition:evaluate())
    end)

    it('returns true when there are no operations', function()
      assert.is_true(Condition.new():evaluate())
    end)
  end)
end)
