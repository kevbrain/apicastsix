--- @module resty.concurrent

local ImmediateExecutor = require('resty.concurrent.immediate_executor')
local TimerPoolExecutor = require('resty.concurrent.timer_pool_executor')

--- @type Executor
local _M = {
    default = ImmediateExecutor,
    immediate = ImmediateExecutor,
    timer_pool = TimerPoolExecutor,
}

--- @function from_options
--- @static
--- @tparam ?table options
--- @tparam nil|table|string|Executor options.executor
function _M.from_options(options)
    local executor = options and options.executor or nil

    if type(executor) == 'string' then
        return _M[executor] or error('unknown executor: ' .. executor)
    elseif executor then
        return executor
    else
        return _M.default
    end
end


return _M
