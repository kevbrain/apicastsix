local TimerTask = require('resty.concurrent.timer_task')
local ngx_timer = ngx.timer

describe('TimerTask', function()
  local test_task = function() end

  before_each(function()
    TimerTask.active_tasks = {}
  end)

  describe('.register_task', function()
    it('adds an ID to the list of active tasks', function()
      local id = '1'

      TimerTask.register_task(id)

      assert.is_true(TimerTask.task_is_active(id))
    end)
  end)

  describe('.unregister_task', function()
    local id = '1'

    setup(function()
      TimerTask.register_task(id)
    end)

    it('removes an ID to the list of active tasks', function()
      TimerTask.unregister_task(id)
      assert.is_false(TimerTask.task_is_active(id))
    end)
  end)

  describe(':new', function()
    it('adds the task to the list of active tasks', function()
      local task = TimerTask.new(test_task)

      assert.is_true(TimerTask.task_is_active(task.id))
    end)

    it('sets a default interval of 60s when not specified', function()
      local task = TimerTask.new(test_task)

      assert.equals(60, task.interval)
    end)

    it('allows to set a running interval', function()
      local interval = 10

      local task = TimerTask.new(test_task, { interval = interval })

      assert.equals(interval, task.interval)
    end)

    it('allows to set arguments for the task', function()
      local args = { '1', '2' }

      local task = TimerTask.new(test_task, { args = args })

      assert.same(args, task.args)
    end)
  end)

  describe(':cancel', function()
    it('removes the task from the list of active tasks', function()
      local task = TimerTask.new(test_task)

      task:cancel()

      assert.is_false(TimerTask.task_is_active(task.id))
    end)
  end)

  describe(':execute', function()
    local func = test_task
    local ngx_timer_stub

    local args = { '1', '2', '3' }
    local interval = 10

    before_each(function()
      ngx_timer_stub = stub(ngx_timer, 'at')
    end)

    describe('when the task is active', function()
      it('runs the task', function()
        local timer_task = TimerTask.new(func, { args = args, interval = interval })
        local func_stub = stub(timer_task, 'task')

        timer_task:execute(true)

        assert.stub(func_stub).was_called_with(unpack(args))
      end)

      it('schedules the next one', function()
        local timer_task = TimerTask.new(func, { args = args, interval = interval })

        timer_task:execute(true)

        assert.stub(ngx_timer_stub).was_called()
      end)
    end)

    describe('when the task is not active', function()
      it('does not run the task', function()
        local timer_task = TimerTask.new(func, { args = args, interval = interval })
        local func_stub = stub(timer_task, 'task')
        timer_task:cancel()

        timer_task:execute(true)

        assert.stub(func_stub).was_not_called()
      end)

      it('does not schedule another task', function()
        local timer_task = TimerTask.new(func, { args = args, interval = interval })
        timer_task:cancel()

        timer_task:execute(true)

        assert.stub(ngx_timer_stub).was_not_called()
      end)
    end)

    describe('when the option to wait an interval instead of running now is passed', function()
      it('does not run the task inmediately', function()
        local timer_task = TimerTask.new(func, { args = args, interval = interval })
        local func_stub = stub(timer_task, 'task')

        timer_task:execute(false)

        -- It will be called in 'interval' seconds, but not now
        assert.stub(func_stub).was_not_called()
      end)

      it('schedules the next one', function()
        local timer_task = TimerTask.new(func, { args = args, interval = interval })

        timer_task:execute(false)

        assert.stub(ngx_timer_stub).was_called()
      end)
    end)
  end)

  it('cancels itself when it is garbage collected', function()
    local timer_task = TimerTask.new(test_task)
    local id = timer_task.id

    timer_task = nil
    collectgarbage()

    assert.is_false(TimerTask.task_is_active(id))
  end)
end)
