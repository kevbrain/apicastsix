--- Policy module
-- Policies should define a method for each of the nginx phases (rewrite,
-- access, etc.) in which they want to run code. When Apicast runs each of
-- those phases, if the policy has been loaded, it will run the code in the
-- method with the phase name. So for example, if we want to define a policy
-- that needs to execute something in the rewrite phase, we need to write
-- a 'rewrite' method.

local _M = { }

local PHASES = {
    'init', 'init_worker',
    'rewrite', 'access',
    'content', 'balancer',
    'header_filter', 'body_filter',
    'post_action',  'log'
}

local setmetatable = setmetatable
local ipairs = ipairs

local noop = function() end

--- Initialize new policy
-- Returns a new policy that you can extend however you want.
-- @tparam string name Name of the new policy.
-- @tparam string version Version of the new policy. Default value is 0.0
-- @treturn policy New policy
function _M.new(name, version)
    local policy = {
        _NAME = name,
        _VERSION = version or '0.0',
    }
    local mt = { __index = policy }

    function policy.new()
        return setmetatable({}, mt)
    end

    for _, phase in _M.phases() do
        policy[phase] = noop
    end

    return policy
end

function _M.phases()
    return ipairs(PHASES)
end

return _M
