--- Headers policy
-- This policy allows to include custom headers that will be sent to the
-- upstream as well as modify or delete the ones included in the original
-- request.
-- Similarly, this policy also allows to add, modify, and delete the headers
-- included in the response.

local ipairs = ipairs
local type = type
local insert = table.insert

local policy = require('apicast.policy')
local _M = policy.new('Headers policy')

local new = _M.new

local function new_header_value(current_value, value_to_add)
  local new_value = current_value or {}

  if type(new_value) == 'string' then
    new_value = { new_value }
  end

  insert(new_value, value_to_add)
  return new_value
end

local function push_request_header(header_name, value, req_headers)
  local new_value = new_header_value(req_headers[header_name], value)
  ngx.req.set_header(header_name, new_value)
end

local function set_request_header(header_name, value)
  ngx.req.set_header(header_name, value)
end

local function add_request_header(header_name, value, req_headers)
  if req_headers[header_name] then
    push_request_header(header_name, value, req_headers)
  end
end

local function push_resp_header(header_name, value)
  local new_value = new_header_value(ngx.header[header_name], value)
  ngx.header[header_name] = new_value
end

local function set_resp_header(header_name, value)
  ngx.header[header_name] = value
end

local function add_resp_header(header_name, value)
  if ngx.header[header_name] then
    push_resp_header(header_name, value)
  end
end

local command_functions = {
  request = {
    push = push_request_header,
    add = add_request_header,
    set = set_request_header
  },
  response = {
    push = push_resp_header,
    add = add_resp_header,
    set = set_resp_header
  }
}

-- header_type can be 'request' or 'response'.
local function run_commands(commands, header_type, ...)
  for _, command in ipairs(commands) do
    local command_func = command_functions[header_type][command.op]
    command_func(command.header, command.value, ...)
  end
end

-- Initialize the config so we do not have to check for nulls in the rest of
-- the code.
local function init_config(config)
  local res = config or {}
  res.request = res.request or {}
  res.response = res.response or {}
  return res
end

--- Initialize a Headers policy
-- @tparam[opt] table config
-- @field[opt] request Table with the operations to apply to the request headers
-- @field[opt] response Table with the operations to apply to the response headers
-- Each operation is a table with three elements:
--   1) op: can be 'add', 'set' or 'push'.
--   2) header
--   3) value
-- The push operation:
--   1) When the header is not set, creates it with the given value.
--   2) When the header is set, it creates a new header with the same name and
--      the given value.
-- The set operation:
--   1) When the header is not set, creates it with the given value.
--   2) When the header is set, replaces its value with the given one.
--   3) Deletes a header when the value is "".
-- The add operation:
--   1) When the header is not set, it does nothing.
--   2) When the header is set, it creates a new header with the same name and
--      the given value.
function _M.new(config)
  local self = new()
  self.config = init_config(config)
  return self
end

function _M:rewrite()
  -- This is here to avoid calling ngx.req.get_headers() in every command
  -- applied to the request headers.
  local req_headers = ngx.req.get_headers() or {}
  run_commands(self.config.request, 'request', req_headers)
end

function _M:header_filter()
  run_commands(self.config.response, 'response')
end

return _M
