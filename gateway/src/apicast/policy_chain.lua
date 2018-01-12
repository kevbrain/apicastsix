--- PolicyChain module
-- A policy chain is simply a sorted list of policies. The policy chain
-- defines a method for each one of the nginx phases (rewrite, access, etc.).
-- Each of those methods simply calls the same method on each of the policies
-- of the chain that implement that method. The calls are made following the
-- order that the policies have in the chain.

local setmetatable = setmetatable
local error = error
local rawset = rawset
local type = type
local require = require
local insert = table.insert
local noop = function() end

require('apicast.loader')

local linked_list = require('apicast.linked_list')
local policy_phases = require('apicast.policy').phases

local _M = {

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

--- Build a policy chain
-- Builds a new policy chain from a list of modules representing policies.
-- If no modules are given, 'apicast' will be used.
-- @tparam table modules Each module can be a string or an object. If the
--  module is a string, the result of require(module).new() will be added to
--  the chain. If it's an object, it will added as is to the chain.
-- @treturn PolicyChain New PolicyChain
function _M.build(modules)
    local chain = {}
    local list = modules or { 'apicast.policy.apicast' }

    for i=1, #list do
        -- TODO: make this error better, possibly not crash and just log and skip the module
        chain[i] = _M.load(list[i]) or error("module " .. list[i] .. ' could not be loaded')
    end

    return _M.new(chain)
end


local DEFAULT_POLICIES = {
    'apicast.policy.load_configuration',
    'apicast.policy.find_service',
    'apicast.policy.local_chain'
}

--- Return new policy chain with default policies.
-- @treturn PolicyChain
function _M.default()
    return _M.build(DEFAULT_POLICIES)
end

--- Load a module
-- If the module is a string, returns the result of initializing it with the
-- given arguments. Otherwise, this function simply returns the module
-- received.
-- @tparam string|table module the module or its name
-- @tparam ?table ... params needed to initialize the module
-- @treturn object The module instantiated
function _M.load(module, ...)
    if type(module) == 'string' then
        ngx.log(ngx.DEBUG, 'loading policy module: ', module)
        local mod = require(module)

        if mod then
            return mod.new(...)
        else
            return mod
        end
    else
        return module
    end
end

--- Initialize new @{PolicyChain}.
-- @treturn PolicyChain
function _M.new(list)
    local chain = list or {}

    local self = setmetatable(chain, mt)
    chain.config = self:export()
    return self
end

---------------------
--- @type PolicyChain
-- An instance of @{policy_chain}.

--- Export the shared context of the chain
-- @treturn linked_list The context of the chain. Note: the list returned is
--   read-only.
function _M:export()
    local chain = self.config

    if chain then return chain end

    for i=#self, 1, -1 do
        local export = self[i].export or noop
        chain = linked_list.readonly(export(self[i]), chain)
    end

    return chain
end

--- Freeze the policy chain to prevent modifications.
-- After calling this method it won't be possible to insert more policies.
-- @treturn PolicyChain returns self
function _M:freeze()
    self.frozen = true
    return self
end

--- Insert a policy into the chain
-- @tparam Policy policy the policy to be added to the chain
-- @tparam[opt] int position the position to add the policy to, defaults to last one
-- @treturn int lenght of the chain
-- @error frozen | returned when chain is not modifiable
-- @see freeze
function _M:insert(policy, position)
    if self.frozen then
        return nil, 'frozen'
    else
        insert(self, position or #self+1, policy)
        return #self
    end
end

local function call_chain(phase_name)
    return function(self, ...)
        for i=1, #self do
            ngx.log(ngx.DEBUG, 'policy chain execute phase: ', phase_name, ', policy: ', self[i]._NAME, ', i: ', i)
            self[i][phase_name](self[i], ...)
        end
    end
end

for _,phase in policy_phases() do
    _M[phase] = call_chain(phase)
end

return _M.build():freeze()
