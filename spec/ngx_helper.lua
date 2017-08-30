local busted = require('busted')
local misc = require('resty.core.misc')

local ngx_var = ngx.var
local ngx_ctx = ngx.ctx
local ngx_shared = ngx.shared
local ngx_header = ngx.header

local register_getter = misc.register_ngx_magic_key_getter
local register_setter = misc.register_ngx_magic_key_setter

local function getlocal(fn, var)
  local i = 1
  while true do
    local name, val = debug.getupvalue(fn, i)
    if name == var then
      return val
    elseif not name then
      break
    end
    i = i + 1
  end
end

local get_status = getlocal(register_getter, 'ngx_magic_key_getters').status
local set_status = getlocal(register_setter, 'ngx_magic_key_setters').status

local function cleanup()
  ngx.var = ngx_var
  ngx.ctx = ngx_ctx
  ngx.shared = ngx_shared
  ngx.header = ngx_header

  register_getter('status', get_status)
  register_setter('status', set_status)
end

local function setup()
  local status

  register_setter('status', function(newstatus)
    status = newstatus
  end)

  register_getter('status', function() return status end)

  ngx.ctx = { }
  ngx.header = { }
end

busted.after_each(cleanup)
busted.teardown(cleanup)

busted.before_each(setup)
