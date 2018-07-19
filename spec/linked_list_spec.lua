local linked_list = require 'apicast.linked_list'

describe('linked_list', function()
  describe('readonly', function()
    it('returns a list that finds elements in the correct order', function()
      local list = linked_list.readonly(
        { a = 1 }, linked_list.readonly({ b = 2 }, { c = 3, a = 10 }))

      assert.equals(1, list.a) -- appears twice; returns the first
      assert.equals(2, list.b)
      assert.equals(3, list.c)
    end)

    it('returns a list that cannot be modified', function()
      local list = linked_list.readonly({ a = 1 })

      assert.has_error(function() list.abc = 123 end, 'readonly list')
      assert.is_nil(list.abc)
    end)

    it('returns a list that has pointers to current and next elements', function()
      local list = linked_list.readonly(
        { a = 1 }, linked_list.readonly({ b = 2 }, { c = 3 }))

      assert.same({ a = 1 }, list.current)
      assert.same({ b = 2 }, list.next.current)
      assert.same({ c = 3 }, list.next.next)
    end)

    it('takes false over nil', function()
      local list = linked_list.readonly({ a = false }, { a = 'value' })

      assert.is_false(list.a)
    end)
  end)

  describe('readwrite', function()
    it('returns a list that finds elements in the correct order', function()
      local list = linked_list.readwrite(
        { a = 1 }, linked_list.readwrite({ b = 2 }, { c = 3, a = 10 }))

      assert.equals(1, list.a) -- appears twice; returns the first
      assert.equals(2, list.b)
      assert.equals(3, list.c)
    end)

    it('returns a list that can be modified', function()
      local list = linked_list.readwrite({ a = 1 })

      list.abc = 123
      assert.equals(123, list.abc)
      assert.same({ a = 1, abc = 123 }, list.current)
    end)

    it('returns a list that has pointers to current and next elements', function()
      local list = linked_list.readwrite(
        { a = 1 }, linked_list.readwrite({ b = 2 }, { c = 3 }))

      assert.same({ a = 1 }, list.current)
      assert.same({ b = 2 }, list.next.current)
      assert.same({ c = 3 }, list.next.next)
    end)

    it('can override values with false', function()
      local list = linked_list.readwrite({  }, { a = 'value' })

      list.a = false

      assert.is_false(list.a)
    end)
  end)
end)
