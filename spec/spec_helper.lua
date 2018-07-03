require 'ngx_helper'
require 'luassert_helper'
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

busted.subscribe({ 'file', 'start' }, function ()
  require('apicast.loader')
end)

busted.subscribe({ 'file', 'end' }, function ()
  collectgarbage()
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
