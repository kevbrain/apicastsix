--- Executor module
-- The executor has a policy chain and will simply forward the calls it
-- receives to that policy chain. It also manages the 'context' that is passed
-- when calling the policy chain methods. This 'context' contains information
-- shared among policies.

local policy_chain = require('policy_chain')
local policy = require('policy')
local linked_list = require('linked_list')

local setmetatable = setmetatable

local _M = { }

local DEFAULT_POLICIES = {
    'policy.load_configuration',
    'policy.find_service',
    'policy.local_chain'
}

local mt = { __index = _M }

-- forward all policy methods to the policy chain
for _,phase in policy.phases() do
    _M[phase] = function(self, ...)
        return self.policy_chain[phase](self.policy_chain, self:context(phase), ...)
    end
end

local function global_chain()
    return policy_chain.build(DEFAULT_POLICIES)
end

function _M.new()
    return setmetatable({ policy_chain = global_chain() }, mt)
end

local function build_context(executor)
    local config = executor.policy_chain:export()

    return linked_list.readwrite({}, config)
end

local function shared_build_context(executor)
    local ctx = ngx.ctx or {}
    local context = ctx.context

    if not context then
        context = build_context(executor)

        ctx.context = context
    end

    return context
end

--- Shared context among policies
-- @tparam string phase Nginx phase
-- @treturn linked_list The context. Note: The list returned is 'read-write'.
function _M:context(phase)
    if phase == 'init' then
        return build_context(self)
    end

    return shared_build_context(self)
end

return _M.new()
