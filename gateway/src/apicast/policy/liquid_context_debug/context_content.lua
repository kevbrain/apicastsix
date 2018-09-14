local type = type
local pairs = pairs
local tostring = tostring

local _M = {}

-- The context usually contains a lot of information. For example, it includes
-- the whole service configuration. Also, some of the values are objects that
-- we can't really use when evaluating liquid, like functions.
-- That's why we define only a few types of keys and values to return.
local accepted_types_for_keys = {
  string = true,
  number = true,
}

local accepted_types_for_values = {
  string = true,
  number = true,
  table = true
}

-- In the context, there might be large integers as keys. This can be a problem
-- when converting to JSON. Imagine an entry of the table like this:
-- { [10000] = 'something' }. To convert that to JSON, we need an array of 1000
-- positions with only one occupied. With arrays like these, 'cjson' raises an
-- "Excessively sparse arrays" error:
-- https://github.com/efelix/lua-cjson/blob/4f27182acabc435fcc220fdb710ddfaf4e648c86/README#L140
-- For example, there is a lrucache instance with a table that maps service ids
-- (numbers) to hosts. So we can have something like { [123456] = "127.0.0.1" }.
-- This can be limited using a global setting of the 'cjson' library. However,
-- we're going to implement an add-hoc solution here so we don't affect the
-- other modules. We're going to convert those large ints to strings as a
-- workaround.
local max_integer_key = 1000

local avoid_circular_refs_msg = {
  already_seen = 'ALREADY SEEN - NOT CALCULATING AGAIN TO AVOID CIRCULAR REFS'
}

local function key(k)
  if type(k) ~= 'number' then return k end

  if k <= max_integer_key then
    return k
  else
    return tostring(k)
  end
end

local value_from

local ident = function(...) return ... end
local value_from_fun = {
  string = ident, number = ident,
  table = function(table, already_seen)
    if already_seen[table] then return avoid_circular_refs_msg end
    already_seen[table] = true

    local res = {}
    for k, v in pairs(table) do
      local wanted_types = accepted_types_for_keys[type(k)] and
                           accepted_types_for_values[type(v)]

      if wanted_types then
        res[key(k)] = value_from(v, already_seen)
      end
    end

    return res
  end
}

value_from = function(object, already_seen)
  local fun = value_from_fun[type(object)]
  if fun then return fun(object, already_seen) end
end

local function add_content(object, acc, already_seen)
  if type(object) ~= 'table' then return nil end

  -- The context is a list where each element has a "current" and a "next".
  local current = object.current
  local next = object.next

  local values_of_current = value_from(current or object, already_seen)

  for k, v in pairs(values_of_current) do
    if acc[key(k)] == nil then -- to return only the first occurrence
      acc[key(k)] = v
    end
  end

  if next then
    add_content(next, acc, already_seen)
  end
end

function _M.from(context)
  local res = {}

  -- Keep an already_seen array to avoid circular references and entering
  -- infinite loops.
  local already_seen = { [context] = true }

  add_content(context, res, already_seen)

  return res
end

return _M
