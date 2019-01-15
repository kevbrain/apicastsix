local setmetatable = setmetatable
local ipairs = ipairs
local assert = assert

local _M = {}

local mt = { __index = _M }

local default_combine_op = 'and'

local function all_true(operations, context)
  for _, operation in ipairs(operations) do
    if not operation:evaluate(context) then
      return false
    end
  end

  return true
end

local function at_least_one_true(operations, context)
  for _, operation in ipairs(operations) do
    if operation:evaluate(context) then
      return true
    end
  end

  return false
end

local evaluate_func = {
  ['and'] = all_true,
  ['or'] = at_least_one_true,
  ['true'] = function() return true end
}

function _M.new(operations, combine_op)
  local self = setmetatable({}, mt)

  if not operations then
    -- If there's nothing to evaluate, return true.
    self.evaluate_func = evaluate_func['true']
  else
    self.evaluate_func = evaluate_func[combine_op or default_combine_op]
  end

  assert(self.evaluate_func, 'Unsupported combine op')

  self.operations = operations

  return self
end

function _M:evaluate(context)
  return self.evaluate_func(self.operations, context)
end

return _M
