local busted = require('busted')
local misc = require('resty.core.misc')
local deepcopy = require('pl.tablex').deepcopy

local ngx_var_original = deepcopy(ngx.var)
local ngx_ctx_original = deepcopy(ngx.ctx)
local ngx_shared_original = deepcopy(ngx.shared)
local ngx_header_original = deepcopy(ngx.header)

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

local function reset_ngx_state()
  ngx.var = deepcopy(ngx_var_original)
  ngx.ctx = deepcopy(ngx_ctx_original)
  ngx.shared = deepcopy(ngx_shared_original)
  ngx.header = deepcopy(ngx_header_original)
end

local function cleanup()
  register_getter('status', get_status)
  register_setter('status', set_status)
  reset_ngx_state()
end

local function setup()
  local status

  register_setter('status', function(newstatus)
    status = newstatus
  end)

  register_getter('status', function() return status end)
end

busted.after_each(cleanup)
busted.teardown(cleanup)

busted.before_each(setup)
