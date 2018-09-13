local LinkedList = require 'apicast.linked_list'
local context_content = require 'apicast.policy.liquid_context_debug.context_content'
local TemplateString = require 'apicast.template_string'
local ngx_variable = require 'apicast.policy.ngx_variable'

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

    it('does not crash when there is a rendered liquid template in the context', function()
      -- avoid stubbing all the ngx.var.* and ngx.req.* in the available context
      stub(ngx_variable, 'available_context', function(context) return context end)

      local template_string = TemplateString.new('{{ service.id }}', 'liquid')
      local context = LinkedList.readonly({ template_string = template_string })

      -- template_string stores the context passed, so now we have a reference
      -- to the context in an element of the context.
      template_string:render(context)

      assert(context_content.from(context))
    end)
  end)
end)
