require 'ffi'
require 'resty.lrucache'
require 'resty.aes'
require 'resty.hmac'

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
end

busted.before_each(reset)
busted.after_each(reset)
