--- @module resty.concurrent

local setmetatable = setmetatable
local unpack = unpack

local Executor = require('resty.concurrent.executor')
local SafeTaskExecutor = require('resty.concurrent.safe_task_executor')
local Event = require('resty.concurrent.event')

--- @type Future
-- Executes task asynchronously, but allows to wait for its return value.
local _M = { }

local instance = setmetatable({ }, { __index = _M })
local mt = { __index = instance }

local noop = function() end
local none = setmetatable({}, { __newindex = noop })

--- @static
--- @param task fun(...):any callable object to execute
--- @param options table
--- @param options.executor table|string|nil
--- @param options.args table to execute the task with
--- @field[type=string] state
--- @treturn Future
function _M.new(task, options)
    local opts = options or none
    return setmetatable({
        task = task,
        event = Event.new(),
        executor = Executor.from_options(options),
        args = opts.args or none,
        state = 'unscheduled',
    }, mt)
end

local function complete(self, success, value, reason)
    if success then
        self._value = value
        self.state = 'fulfilled'
    else
        self.reason = reason
        self.state = 'rejected'
    end

    self.event:set()
end

local function compare_and_set_state(self, next_state, expected_current)
    if not next_state or not expected_current then
        return nil, 'missing state'
    end

    if expected_current == self.state then
        self.state = next_state
        return true
    else
        return false
    end
end

local function safe_execute(self, task, args)
    if compare_and_set_state(self, 'processing', 'pending') then
        local success, value, reason = SafeTaskExecutor.execute(task, unpack(args))
        complete(self, success, value, reason)
    end
end

--- Schedule the Future execution.
--- @function execute
--- @usage future:execute()
--- @see new
--- @treturn Future

function instance:execute()
    local executor = self and self.executor

    if not executor then return nil, 'not initialized' end

    local task = self.task
    local args = self.args

    if compare_and_set_state(self, 'pending', 'unscheduled') then
        executor:post(safe_execute, self, task, args)
        return self
    end
end

--- Create the future and schedule execution of the task.
--- @function Future.execute
--- @static
--- @usage local future = Future.execute(function() end, { args = { '1' })
--- @param task fun(...):any callable object to execute
--- @param options table
--- @param options executor
--- @param options.args arguments to execute the task with
--- @treturn Future
function _M.execute(task, options)
    return _M.new(task, options):execute()
end

function _M:value(timeout)
    local event = self and self.event

    if not event then return nil, 'not initialized' end

    event:wait(timeout)

    return self._value
end

return _M
