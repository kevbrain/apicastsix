--- @module resty.concurrent

--- @type ImmediateExecutor

local _M = { }

--- Immediately execute task in current thread.
--- @function ImmediateExecutor:post
function _M.post(_, task, ...)
    return task(...)
end

return _M
