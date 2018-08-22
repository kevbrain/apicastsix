local LinkedList = require 'apicast.linked_list'
local context_content = require 'apicast.policy.liquid_context_debug.context_content'

describe('Context content', function()
  describe('.from', function()
    it('returns the content from a context with one node', function()
      local t = { a = 1, b = 2 }
      local context = LinkedList.readonly(t)

      local content = context_content.from(context)

      assert.contains(t, content)
    end)

    it('returns the content from a context with several nodes', function()
      local context = LinkedList.readonly(
        { a = 1 },
        LinkedList.readonly(
          { b = 2, c = 3 },
          LinkedList.readonly(
            { d = 4 },
            { e = 5, f = 6 }
          )
        )
      )

      local content = context_content.from(context)

      local expected = { a = 1, b = 2, c = 3, d = 4, e = 5, f = 6 }
      assert.contains(expected, content)
    end)

    it('returns only the first value of a repeated element', function()
      local context = LinkedList.readonly(
        { a = 1 },
        LinkedList.readonly(
          { a = 2 },
          LinkedList.readonly(
            { a = 3 },
            { a = 4 }
          )
        )
      )

      local content = context_content.from(context)

      assert.equals(1, content.a)
    end)

    it('ignores keys that are not strings or numbers', function()
      local context = LinkedList.readonly(
        { a = 1, [function() end] = 2, [{}] = 3 }
      )

      local content = context_content.from(context)

      assert.contains({ a = 1 }, content)
    end)

    it('ignores values that are not strings, numbers or tables', function()
      local context = LinkedList.readonly(
        { a = 1, b = {}, c = function() end }
      )

      local content = context_content.from(context)

      assert.contains({ a = 1, b = {} }, content)
    end)

    it('returns empty if the context is empty', function()
      assert.same({}, context_content.from({}))
    end)
  end)
end)
