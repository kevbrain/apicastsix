local setmetatable = setmetatable

local _M, mt = require('policy').new()

local configuration_loader = require('configuration_loader').new()
local configuration_store = require('configuration_store')

function _M.new()
    return setmetatable({
        configuration = configuration_store.new(),
    }, mt)
end

function _M:export()
    return {
        configuration = self.configuration
    }
end

function _M:init()
    configuration_loader.init(self.configuration)
end

function _M:init_worker()
    configuration_loader.init_worker(self.configuration)
end

function _M:rewrite(context)
    context.host = context.host or ngx.var.host
    context.configuration = configuration_loader.rewrite(self.configuration, context.host)
end

return _M
