local Operation = require('apicast.conditions.operation')
local ngx_variable = require('apicast.policy.ngx_variable')

describe('Operation', function()
  before_each(function()
    -- avoid stubbing all the ngx.var.* and ngx.req.* in the available context
    stub(ngx_variable, 'available_context', function(context) return context end)
  end)

  describe('.new', function()
    it('raises error with an unsupported operation', function()
      local res, err = pcall(Operation.new, '1', 'plain', '<>', '1', 'plain')

      assert.is_falsy(res)
      assert.is_truthy(err)
    end)
  end)

  describe('.evaluate', function()
    it('evaluates ==', function()
      assert.is_true(Operation.new('1', 'plain', '==', '1', 'plain'):evaluate({}))
      assert.is_false(Operation.new('1', 'plain', '==', '2', 'plain'):evaluate({}))
    end)

    it('evaluates !=', function()
      assert.is_true(Operation.new('1', 'plain', '!=', '2', 'plain'):evaluate({}))
      assert.is_false(Operation.new('1', 'plain', '!=', '1', 'plain'):evaluate({}))
    end)

    it('evaluates values as plain text by default', function()
      assert.is_true(Operation.new('1', nil, '==', '1', nil):evaluate({}))
      assert.is_false(Operation.new('1', nil, '==', '2', nil):evaluate({}))
    end)

    it('evaluates liquid when indicated in the types', function()
      local context = { var_1 = '1', var_2 = '2' }

      local res_true = Operation.new(
        '{{ var_1 }}', 'liquid', '==', '1', 'plain'
      ):evaluate(context)

      assert.is_true(res_true)

      local res_false = Operation.new(
        '{{ var_1 }}', 'liquid', '==', '{{ var_2 }}', 'liquid'
      ):evaluate(context)

      assert.is_false(res_false)
    end)

    it('evaluates comparison ops without differentiating types', function()
      local context = { var_1 = 1 }

      local eq_int_and_string = Operation.new(
        '{{ var_1 }}', 'liquid', '==', '1', 'plain'
      ):evaluate(context)

      assert.is_true(eq_int_and_string)

      local not_eq_int_and_string = Operation.new(
        '{{ var_1 }}', 'liquid', '!=', '1', 'plain'
      ):evaluate(context)

      assert.is_false(not_eq_int_and_string)
    end)
  end)
end)
