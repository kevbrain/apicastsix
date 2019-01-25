--- nasty monkey patch to create new notification for the whole it block
--- busted does not have builtin way of having a hook around a test with its before/after hooks
do
  local function getlocal(fn, var)
    local i = 1
    while true do
      local name, val = debug.getlocal(fn + 1, i)
      if name == var then
        return val
      elseif not name then
        break
      end
      i = i + 1
    end
  end

  local function getupvalue(fn, var)
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

  --- busted/runner.lua:147 is 5 stacks above
  -- https://github.com/Olivine-Labs/busted/blob/v2.0.rc12-1/busted/runner.lua#L147
  local busted = getlocal(5, 'busted')
  --- busted/core.lua:240 has "executors" upvalue available
  -- https://github.com/Olivine-Labs/busted/blob/v2.0.rc12-1/busted/core.lua#L240
  local executors = getupvalue(busted.register, 'executors')
  --- busted/init.lua:20 defines the "it" method we want to wrap around
  -- https://github.com/Olivine-Labs/busted/blob/v2.0.rc12-1/busted/init.lua#L20
  local it = executors.it

  busted.register('it', function(element)
    local parent = busted.context.parent(element)

    if busted.safe_publish('it', { 'it', 'start' }, element, parent) then
      it(element)
    end

    busted.safe_publish('it', { 'it', 'end' }, element, parent)
  end)
end

require 'luassert_helper'
require 'ngx_helper'
require 'jwt_helper'

local busted = require('busted')
local env = require('resty.env')

local previous_env = {}
local set = env.set
local null = {'null'}

-- override resty.env.set with custom function that remembers previous values
env.set = function(name, ...)
  local previous = set(name, ...)

  if not previous_env[name] then
    previous_env[name] = previous or null
  end

  return previous
end

-- so they can be reset back to the values before the test run
local function reset()
  for name, value in pairs(previous_env) do
    if value == null then
      value = nil
    end
    set(name, value)
  end

  previous_env = {}

  env.reset()

  -- To make sure that we are using valid policy configs in the tests.
  set('APICAST_VALIDATE_POLICY_CONFIGS', true)
end

busted.before_each(reset)
busted.after_each(reset)

local resty_proxy = require('resty.http.proxy')

busted.before_each(function()
  resty_proxy:reset()
end)

local resty_resolver = require 'resty.resolver'
busted.before_each(resty_resolver.reset)

busted.subscribe({ 'file', 'start' }, function ()
  require('apicast.loader')
  return nil, true -- needs to return true as second return value to continue executing the chain
end)

busted.subscribe({ 'file', 'end' }, function ()
  collectgarbage()
  return nil, true
end)

do
  -- busted does auto-insulation and tries to reload all files for every test file
  -- that breaks ffi.cdef as it can't be called several times with the same argument
  -- backports https://github.com/Olivine-Labs/busted/commit/db6d8b4be8fd099ab387efeb8232cfd905912abb
  local ffi = require('ffi')
  local cdef = ffi.cdef
  local cdef_cache = {}

  function ffi.cdef(def)
    if not cdef_cache[def] then
      cdef(def)
      cdef_cache[def] = true
    end
  end
end

_G.fixture = function (...)
  local path = require('pl.path')
  local file = require('pl.file')

  return file.read(path.join('spec', 'fixtures', ...)) or file.read(path.join('t', 'fixtures', ...))
end

do -- stub http_ng
  local http_ng = require('resty.http_ng')
  local test_backend_client = require 'resty.http_ng.backend.test'
  local test_backend
  local stub = require('luassert.stub')
  local stubbed

  busted.before_each(function()
    test_backend = test_backend_client.new()
    stubbed = stub(http_ng, 'backend', test_backend)
  end)

  busted.after_each(function()
    test_backend.verify_no_outstanding_expectations()
    stubbed:revert()
  end)
end
