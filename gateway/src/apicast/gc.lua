-- In LuaJIT and Lua 5.1, the __gc metamethod does not work in tables, it only
-- works in "userdata". This module introduces a workaround to make it work
-- with tables.

local rawgetmetatable = debug.getmetatable
local getmetatable = getmetatable
local setmetatable = setmetatable
local newproxy = newproxy
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local table = table
local unpack = unpack
local error = error
local tostring = tostring

local _M = {}

local function original_table(proxy)
  return rawgetmetatable(proxy).__table
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
  local ok = table.remove(ret, 1)

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

return _M
