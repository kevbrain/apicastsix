pcall(require, 'luarocks.loader')

-- src/?/policy.lua allows us to require apicast.policy.apolicy
package.path = package.path .. ";./src/?.lua;./src/?/policy.lua"

local configuration = require 'apicast.configuration_loader'

local config = configuration.boot()

ngx.say(config)
