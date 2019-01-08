--- RoutingOperation
-- This module is based on the Operation one. The only difference is that
-- operations for the routing policy check request information that is not
-- available when the operation is instantiated, like headers, query arguments,
-- etc. That is the reason why in instances of this module, there are functions
-- to get the left operand instead of the operand itself.

local setmetatable = setmetatable
local Operation = require('apicast.conditions.operation')

local _M = {}

local mt = { __index = _M }

local function new(evaluate_left_side_func, op, value)
  local self = setmetatable({}, mt)

  self.evaluate_left_side_func = evaluate_left_side_func
  self.op = op
  self.value = value

  return self
end

function _M.new_op_with_path(op, value)
  local eval_left_func = function(request) return request:get_uri() end
  return new(eval_left_func, op, value)
end

function _M.new_op_with_header(header_name, op, value)
  local eval_left_func = function(request)
    return request:get_header(header_name)
  end

  return new(eval_left_func, op, value)
end

function _M.new_op_with_query_arg(query_arg_name, op, value)
  local eval_left_func = function(request)
    return request:get_uri_arg(query_arg_name)
  end

  return new(eval_left_func, op, value)
end

function _M.new_op_with_jwt_claim(jwt_claim_name, op, value)
  local eval_left_func = function(request)
    local jwt = request:get_validated_jwt()
    return (jwt and jwt[jwt_claim_name]) or nil
  end

  return new(eval_left_func, op, value)
end

function _M:evaluate(context)
  local left_operand_val = self.evaluate_left_side_func(context.request)

  local op = Operation.new(
    left_operand_val, 'plain', self.op, self.value, 'plain'
  )

  return op:evaluate(context)
end

return _M
