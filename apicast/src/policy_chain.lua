local resty_env = require('resty.env')

if resty_env.get('APICAST_MODULE') then
    return require('module')
end

local setmetatable = setmetatable

local _M = {

}

local mt = { __index = _M }

function _M.build(modules)
    local chain = {}
    local list = modules or { 'apicast' }

    for i=1, #list do
        chain[i] = require(list[i]).new()
    end

    return _M.new(chain)
end

function _M.new(list)
    local chain = list or {}

    return setmetatable(chain, mt)
end

local phases = {
    'init', 'init_worker',
    'rewrite', 'access', 'balancer',
    'header_filter', 'body_filter',
    'post_action',  'log'
}

for i=1, #phases do
    local phase_name = phases[i]

    _M[phase_name] = function(self, ...)
        for i=1, #self do
            self[i][phase_name](self[i], ...)
        end
    end
end

return _M.build()
