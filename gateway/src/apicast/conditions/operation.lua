local setmetatable = setmetatable
local assert = assert
local tostring = tostring
local match = ngx.re.match

local TemplateString = require 'apicast.template_string'

local default_value_type = 'plain'

local _M = {}

local mt = { __index = _M }

local function create_template(value, type)
  return TemplateString.new(value, type or default_value_type)
end

local evaluate_func = {
  ['=='] = function(left, right) return tostring(left) == tostring(right) end,
  ['!='] = function(left, right) return tostring(left) ~= tostring(right) end,

  -- Implemented on top of ngx.re.match. Returns true when there is a match and
  -- false otherwise.
  ['matches'] = function(left, right)
    return (match(tostring(left), tostring(right)) and true) or false
  end
}

--- Initialize an operation
-- @tparam string left Left operand
-- @tparam[opt] string left_type How to evaluate the left operand ('plain' or
--   'liquid'). Default: 'plain'.
-- @tparam string op Operation
-- @tparam[opt] string right Right operand
-- @tparam string right_type How to evaluate the right operand ('plain' or
--   'liquid'). Default: 'plain'.
function _M.new(left, left_type, op, right, right_type)
  local self = setmetatable({}, mt)

  self.evaluate_func = evaluate_func[op]
  assert(self.evaluate_func, 'Unsupported operation')

  self.templated_left = create_template(left, left_type)
  self.templated_right = create_template(right, right_type)

  return self
end

function _M:evaluate(context)
  local left_value = self.templated_left:render(context)
  local right_value = self.templated_right:render(context)

  return self.evaluate_func(left_value, right_value)
end

return _M
