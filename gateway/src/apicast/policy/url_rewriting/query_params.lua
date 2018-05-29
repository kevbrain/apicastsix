local setmetatable = setmetatable
local insert = table.insert
local type = type

local _M = {}

local mt = { __index = _M }

-- Note: This module calls 'ngx.req.set_uri_args()' on each operation
-- If this becomes too costly, we can change it by exposing a method that calls
-- 'ngx.req.set_uri_args()' leaving that responsibility to the caller.

--- Initialize a new QueryStringParams
-- @tparam[opt] table uri_args URI arguments
function _M.new(uri_args)
  local self = setmetatable({}, mt)

  if uri_args then
    self.args = uri_args
  else
    local get_args_err
    self.args, get_args_err = ngx.req.get_uri_args()

    if not self.args then
      ngx.log(ngx.ERR, 'Error while getting URI args: ', get_args_err)
      return nil, get_args_err
    end
  end

  return self
end

--- Updates the URI args
local function update_uri_args(args)
  ngx.req.set_uri_args(args)
end

local function add_to_existing_arg(self, arg, value)
  -- When the argument has a single value, it is a string and needs to be
  -- converted to table so we can add a second one.
  if type(self.args[arg]) ~= 'table' then
    self.args[arg] = { self.args[arg] }
  end

  insert(self.args[arg], value)
end

--- Pushes a value to an argument
-- 1) When the arg is not set, creates it with the given value.
-- 2) When the arg is set, it adds a new value for it (becomes an array if it
--    was not one already).
function _M:push(arg, value)
  if not self.args[arg] then
    self.args[arg] = value
  else
    add_to_existing_arg(self, arg, value)
  end

  update_uri_args(self.args)
end

--- Set a value for an argument
-- 1) When the arg is not set, creates it with the given value.
-- 2) When the arg is set, replaces its value with the given one.
function _M:set(arg, value)
  self.args[arg] = value
  update_uri_args(self.args)
end

--- Adds a value for an argument
-- 1) When the arg is not set, it does nothing.
-- 2) When the arg is set, it adds a new value for it (becomes an array if it
--    was not one already).
function _M:add(arg, value)
  if self.args[arg] then
    add_to_existing_arg(self, arg, value)
    update_uri_args(self.args)
  end
end

--- Deletes an argument
function _M:delete(arg)
  if self.args[arg] then
    self.args[arg] = nil
    update_uri_args(self.args)
  end
end

return _M
