local GC = require('apicast.gc')

describe('GC', function()
  describe('.set_metatable_gc', function()
    it('enables GC on a table', function()
      local test_table = { 1, 2, 3 }
      local test_metatable = { __gc = function() end }
      spy.on(test_metatable, '__gc')

      assert(GC.set_metatable_gc(test_table, test_metatable))
      collectgarbage()

      assert.spy(test_metatable.__gc).was_called()
    end)

    it('returns an object where we can access, add, and delete elements', function()
      local test_table = { 1, 2, 3, some_key = 'some_val' }
      local test_metatable = { __gc = function() end }

      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      assert.equals(3, #table_with_gc)
      assert.equals(1, table_with_gc[1])
      assert.equals('some_val', table_with_gc.some_key)

      table_with_gc.new_key = 'new_val'
      assert.equals('new_val', table_with_gc.new_key)

      table_with_gc.new_key = nil
      assert.is_nil(table_with_gc.new_key)
    end)

    it('returns an object that responds to ipairs', function()
      local test_table = { 1, 2, 3, some_key = 'some_val' }
      local test_metatable = { __gc = function() end }

      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      local res = {}
      for _, val in ipairs(table_with_gc) do
        table.insert(res, val)
      end

      assert.same({ 1, 2, 3 }, res)
    end)

    it('returns an object that responds to pairs', function()
      local test_table = { 1, 2, 3, some_key = 'some_val' }
      local test_metatable = { __gc = function() end }

      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      local res = {}
      for k, v in pairs(table_with_gc) do
        res[k] = v
      end

      assert.same({ [1] = 1, [2] = 2, [3] = 3, some_key = 'some_val' }, res)
    end)

    it('returns an object that respects the __call in the mt passed in the params', function()
      local test_table = { 1, 2, 3 }
      local test_metatable = {
        __gc = function() end,
        __call = function(_, ...)
          local res = 0

          for _, val in ipairs(table.pack(...)) do
            res = res + val
          end

          return res
        end
      }

      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      assert.equals(3, table_with_gc(1, 2))
    end)

    it('returns an object that respects the __tostring in the mt passed in the params', function()
      local test_table = { 1, 2, 3 }
      local test_metatable = {
        __gc = function() end,
        __tostring = function() return '123' end
      }

      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      assert.equals('123', tostring(table_with_gc))
    end)

    it('returns an object that returns an error when it cannot be called', function()
      local test_table = { 1, 2, 3 }
      local test_metatable = { __gc = function() end }

      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      local ok, err = pcall(table_with_gc, 1, 2)

      assert.falsy(ok)

      -- Test that the error is meaningful
      assert.equals('attempt to call a table value', err)
    end)

    it('returns an object that has as a metatable the one sent in the params', function()
      local test_table = { 1, 2, 3 }
      local test_metatable = { __gc = function() end }

      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      assert.same(test_metatable, getmetatable(table_with_gc))
    end)

    it('returns an object that respects the __index in the mt passed in the params', function()
      local test_table = { 1, 2, 3 }
      local test_metatable = {
        __gc = function() end,
        __index = { some_func = function() return 'abc' end }
      }
      local table_with_gc = GC.set_metatable_gc(test_table, test_metatable)

      assert.equals('abc', table_with_gc:some_func())
    end)
  end)
end)
