local _M = {
    PHASES = {
        'init', 'init_worker',
        'rewrite', 'access', 'balancer',
        'header_filter', 'body_filter',
        'post_action',  'log'
    }
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
        _VERSION = version ,
    }
    local mt = { __index = policy }

    function policy.new()
        return setmetatable({}, mt)
    end

    for _, phase in _M:phases() do
        policy[phase] = noop
    end

    return policy
end

function _M:phases()
    return ipairs(self.PHASES)
end

return _M
