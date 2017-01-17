require 'ffi'
require 'resty.lrucache'

require 'ngx_helper'
require 'luassert_helper'

local busted = require('busted')
local env = require('resty.env')

busted.before_each(env.reset)
busted.after_each(env.reset)
