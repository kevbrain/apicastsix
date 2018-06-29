-- In LuaJIT and Lua 5.1, the __gc metamethod does not work in tables, it only
-- works in "userdata". This module introduces a workaround to make it work
-- with tables.

local tab_clone = require "table.clone"

local rawgetmetatable = debug.getmetatable
local getmetatable = getmetatable
local setmetatable = setmetatable
local newproxy = newproxy
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local remove = table.remove
local unpack = unpack
local error = error
local tostring = tostring

local _M = {}

local function original_table(proxy)
  local mt = rawgetmetatable(proxy)

  return mt and mt.__table
end

local function __gc(proxy)
  local t = original_table(proxy)
  local mt = getmetatable(proxy)

  if mt and mt.__gc then mt.__gc(t) end
end

local function __tostring(proxy)
  return tostring(original_table(proxy))
end

local function __call(proxy, ...)
  local t = original_table(proxy)

  -- Try to run __call() and if it's not possible, try to run it in a way that
  -- it returns a meaningful error.
  local ret = { pcall(t, ...) }
  local ok = remove(ret, 1)

  if ok then
    return unpack(ret)
  else
    error(ret[1], 2)
  end
end

local function __len(proxy)
  return #(original_table(proxy))
end

local function __ipairs(proxy)
  return ipairs(original_table(proxy))
end

local function __pairs(proxy)
  return pairs(original_table(proxy))
end

--- Set a __gc metamethod in a table
-- @tparam table t A table
-- @tparam table metatable A table that will be used as a metatable. It needs
--  to define __gc.
function _M.set_metatable_gc(t, metatable)
  setmetatable(t, metatable)

  -- newproxy() returns a userdata instance
  local proxy = newproxy(true)

  -- We are going to define a metatable in the userdata instance to make it act
  -- like a table. To do that, we'll just define the metamethods a table should
  -- respond to.
  local mt = getmetatable(proxy)

  mt.__gc = __gc

  mt.__index = t
  mt.__newindex = t
  mt.__table = t

  mt.__call = __call
  mt.__len = __len
  mt.__ipairs = __ipairs
  mt.__pairs = __pairs
  mt.__tostring = __tostring

  -- Hide the 'mt' metatable. We can access it using 'rawgetmetatable()'
  mt.__metatable = metatable

  return proxy
end

local delegate_mt = {
  __gc = function(self)
    local mt = getmetatable(self.table)

    if mt and mt.__gc then return mt.__gc(self.table) end
  end
}

--- Creates new object that when GC'd will call __gc metamethod on a given table.
--- @tparam table t a table
function _M.delegate(t)
  return _M.set_metatable_gc({ table = t }, delegate_mt)
end

--- Clones given metatable so it is tied to the life of given object.
--- Please not that it first clones the metatable before assigning.
--- @tparam table t a table
--- @tparam table metatable a metatable
function _M.setmetatable_gc_clone(t, metatable)
  local copy = tab_clone(metatable)

  copy.__table = t
  copy.__gc_helper = _M.delegate(t)
  copy.__metatable = metatable

  return setmetatable(t, copy)
end

return _M
