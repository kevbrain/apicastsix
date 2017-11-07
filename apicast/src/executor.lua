local setmetatable = setmetatable

local policy_chain = require('policy_chain')
local linked_list = require('linked_list')

local _M = { }

local mt = { __index = _M }

-- forward all policy methods to the policy chain
for i=1, #(policy_chain.PHASES) do
    local phase_name = policy_chain.PHASES[i]

    _M[phase_name] = function(self, ...)
        return self.policy_chain[phase_name](self.policy_chain, self:context(phase_name), ...)
    end
end

function _M.new()
    local global_chain = policy_chain.build({
        'policy.load_configuration', 'policy.find_service', 'policy.local_chain'
    })

    return setmetatable({ policy_chain = global_chain }, mt)
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

function _M:context(phase)
    if phase == 'init' then
        return build_context(self)
    end

    return shared_build_context(self)
end

return _M.new()
