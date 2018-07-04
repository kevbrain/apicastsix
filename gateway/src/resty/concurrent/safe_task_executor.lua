--- @module resty.concurrent

local setmetatable = setmetatable
local tab_remove = table.remove
local pcall = pcall

--- @type SafeTaskExecutor
--- Safely executes callable objects and returns their status, return value and cause of failure.
local _M = { }
local instance = setmetatable({ }, { __index = _M })

local mt = { __index = instance }

--- @static
--- @param task fun(...):any
--- @treturn SafeTaskExecutor
function _M.new(task)
    return setmetatable({ task = task }, mt)
end

function _M.execute(task, ...)
    return _M.new(task):execute(...)
end

--- Safely execute task and pass it all arguments.
--- @treturn boolean, any, any|string
--- @function SafeTaskExecutor:execute
function instance:execute(...)
    local task = self and self.task

    if not task then return nil, 'not initialized' end

    local ret = { pcall(task, ...) }
    local ok = tab_remove(ret, 1)

    if ok then
        return true, ret
    else
        return false, nil, ret[1]
    end
end

return _M
