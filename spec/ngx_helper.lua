-- not really required, but makes it obvious it is loaded
-- so we can copy ngx object and compare it later to check modifications
require('resty.core')

-- so test can't exit and can verify the return status easily
ngx.exit = function(...) return ... end

local busted = require('busted')
local misc = require('resty.core.misc')
local tablex = require('pl.tablex')
local inspect = require('inspect')
local spy = require('luassert.spy')
local deepcopy = tablex.deepcopy
local copy = tablex.copy

local pairs = pairs

local ngx_original = copy(ngx)
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
local get_headers_sent = getlocal(register_getter, 'ngx_magic_key_getters').headers_sent
local set_headers_sent = getlocal(register_setter, 'ngx_magic_key_setters').headers_sent

local function reset_ngx_shared(state)
  local shared = ngx.shared

  for name, dict in pairs(state) do
    shared[name] = dict
  end

  for name, _ in pairs(shared) do
    shared[name] = state[name]
  end
end

--- ngx keys that are going to be reset in between tests.
local ngx_reset = {
  var = ngx_var_original,
  ctx = ngx_ctx_original,
  header = ngx_header_original,
}

local function reset_ngx_state()
  for key, val in pairs(ngx_reset) do
    ngx[key] = deepcopy(val)
  end

  -- We can't replace the whole table, as some code like resty.limit.req takes reference to it when loading.
  reset_ngx_shared(ngx_shared_original)
end

local function cleanup()
  register_getter('status', get_status)
  register_setter('status', set_status)
  register_getter('headers_sent', get_headers_sent)
  register_setter('headers_sent', set_headers_sent)
  reset_ngx_state()
end

local function setup()
  -- Register getters and setters for ngx vars used in the tests.

  local status, headers_sent

  register_setter('status', function(newstatus)
    status = newstatus
  end)

  register_getter('status', function() return status end)

  register_setter('headers_sent', function(new_headers_sent)
    headers_sent = new_headers_sent
  end)

  register_getter('headers_sent', function() return headers_sent end)
end

--- Verify ngx global variable against unintentional changes.
--- Some specs could be for example setting `ngx.req = { }` and leak
--- to other tests.
busted.subscribe({ 'it', 'end' }, function ()
  for key, value in pairs(ngx_original) do
    if ngx[key] ~= value and not ngx_reset[key] and not spy.is_spy(ngx[key]) then
      ngx[key] = value
      busted.fail('ngx.' .. key .. ' changed from ' .. inspect(value) .. ' to ' .. inspect(ngx[key]))
    end
  end

  return nil, true -- continue executing callbacks
end)

busted.after_each(cleanup)
busted.teardown(cleanup)

busted.before_each(setup)
