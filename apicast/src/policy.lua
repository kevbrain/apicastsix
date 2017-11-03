local _M = {}

local setmetatable = setmetatable
local policy_chain = require('policy_chain')

local noop = function() end

--- Initialize new policy
-- Returns a new policy that you can extend however you want.
-- @tparam string name Name of the new policy.
-- @tparam string version Version of the new policy. Default value is 0.0
-- @treturn policy New policy
function _M.new(name, version)
    local policy = {
        _NAME = name,
        _VERSION = version ,
    }
    local mt = { __index = policy }

    function policy.new()
        return setmetatable({}, mt)
    end

    for i=1,#(policy_chain.PHASES) do
        policy[policy_chain.PHASES[i]] = noop
    end

    return policy
end

return _M
