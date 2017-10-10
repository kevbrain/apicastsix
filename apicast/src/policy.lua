local _M = {}

local setmetatable = setmetatable
local policy_chain = require('policy_chain')

local noop = function() end

function _M.new(name)
    local policy = {
        _NAME = name or 'policy',
        _VERSION = '0.0',
    }
    local mt = { __index = policy }

    function policy.new()
        return setmetatable({}, mt)
    end

    for i=1,#(policy_chain.PHASES) do
        policy[policy_chain.PHASES[i]] = noop
    end

    return policy, mt
end

return _M
