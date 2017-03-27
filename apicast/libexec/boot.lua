pcall(require, 'luarocks.loader')
package.path = package.path .. ";./src/?.lua"

local configuration = require 'configuration_loader'

local config = configuration.boot()

ngx.say(config)
