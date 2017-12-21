package.path = package.path .. ";./src/?.lua;"
require('apicast.loader')

local configuration = require 'apicast.configuration_loader'

local config = configuration.boot()

ngx.say(config)
