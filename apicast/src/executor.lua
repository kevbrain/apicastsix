local setmetatable = setmetatable

local policy_chain = require('policy_chain')
local linked_list = require('linked_list')

local _M = { }

local mt = { __index = _M }

-- forward all policy methods to the policy chain
for i=1, #(policy_chain.PHASES) do
    local phase_name = policy_chain.PHASES[i]

    _M[phase_name] = function(self, ...)
        return self.policy_chain[phase_name](self.policy_chain, self:context(), ...)
    end
end

function _M.new()
    local local_chain = policy_chain.build()

    local load_configuration = policy_chain.load('policy.load_configuration', local_chain)

    local global_chain = policy_chain.build({ load_configuration, local_chain })

    return setmetatable({ policy_chain = global_chain }, mt)
end

function _M:context()
    local config = self.policy_chain:export()

    return linked_list.readwrite({}, config)
end

return _M.new()
