local GC = require 'apicast.gc'

local uuid = require 'resty.jit-uuid'
local unpack = unpack

local _M = {}

local default_interval_seconds = 60

_M.active_tasks = {}

function _M.register_task(id)
  _M.active_tasks[id] = true
end

function _M.unregister_task(id)
  _M.active_tasks[id] = nil
end

function _M.task_is_active(id)
  return _M.active_tasks[id] or false
end

local function generate_id()
  return uuid.generate_v4()
end

local function gc(self)
  _M.unregister_task(self.id)
end

local mt = {
  __gc = gc,
  __index = _M
}

--- Initialize a TimerTask.
-- @tparam function task The function to be run periodically
-- @tparam[opt] table opts
-- @tfield ?table args Arguments to the function
-- @tfield ?number interval Interval in seconds (defaults to 60)
function _M.new(task, opts)
  local options = opts or {}

  local id = generate_id()

  local self = GC.set_metatable_gc({}, mt)
  self.task = task
  self.args = options.args
  self.interval = options.interval or default_interval_seconds
  self.id = id

  _M.register_task(id)

  return self
end

local run_periodic, schedule_next, timer_execute

run_periodic = function(run_now, id, func, args, interval)
  if not _M.task_is_active(id) then return end

  if run_now then
    func(unpack(args))
  end

  schedule_next(id, func, args, interval)
end

-- Note: ngx.timer.at always sends "premature" as the first param.
-- "premature" is boolean value indicating whether it is a premature timer
-- expiration.
timer_execute = function(_, id, func, args, interval)
  run_periodic(true, id, func, args, interval)
end

schedule_next = function(id, func, args, interval)
  local ok, err = ngx.timer.at(interval, timer_execute, id, func, args, interval)

  if not ok then
    ngx.log(ngx.ERR, "failed to schedule timer task: ", err)
  end
end

--- Execute a task
-- @tparam[opt] run_now boolean True to run the task immediately or False to
--   wait 'interval' seconds. (Defaults to false)
function _M:execute(run_now)
  run_periodic(run_now or false, self.id, self.task, self.args, self.interval)
end

function _M:cancel()
  _M.unregister_task(self.id)
end

return _M
