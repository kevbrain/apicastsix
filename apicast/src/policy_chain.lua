local resty_env = require('resty.env')

if resty_env.get('APICAST_MODULE') then
    return require('module')
end

local setmetatable = setmetatable
local insert = table.insert
local error = error
local rawset = rawset
local type = type
local require = require
local noop = function() end

local linked_list = require('linked_list')

local _M = {
    PHASES = {
        'init', 'init_worker',
        'rewrite', 'access', 'balancer',
        'header_filter', 'body_filter',
        'post_action',  'log'
    }
}

local mt = {
    __index = _M,
    __newindex = function(t, k ,v)
        if t.frozen then
            error("readonly table")
        else
            rawset(t, k, v)
        end
    end
}

function _M.build(modules)
    local chain = {}
    local list = modules or { 'apicast' }

    for i=1, #list do
        chain[i] = _M.load(list[i])
    end

    return _M.new(chain)
end

function _M.load(module, ...)
    if type(module) == 'string' then
        return require(module).new(...)
    else
        return module
    end
end

function _M.new(list)
    local chain = list or {}

    local self = setmetatable(chain, mt)
    chain.config = self:export()
    return self:freeze()
end

function _M:freeze()
    self.frozen = true
    return self
end

function _M:add(module)
    insert(self, _M.load(module))
end

function _M:export()
    local chain = self.config

    if chain then return chain end

    for i=#self, 1, -1 do
        local export = self[i].export or noop
        chain = linked_list.readonly(export(self[i]), chain)
    end

    return chain
end

local function call_chain(phase_name)
    return function(self, ...)
        for i=1, #self do
            self[i][phase_name](self[i], ...)
        end
    end
end

for i=1, #(_M.PHASES) do
    local phase_name = _M.PHASES[i]

    _M[phase_name] = call_chain(phase_name)
end

return _M.build()
