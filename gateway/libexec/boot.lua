pcall(require, 'luarocks.loader')
package.path = package.path .. ";./src/?.lua"

local configuration = require 'apicast.configuration_loader'

local config = configuration.boot()

ngx.say(config)
