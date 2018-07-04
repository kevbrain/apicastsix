local SafeTaskExecutor = require('resty.concurrent.safe_task_executor')

describe('SafeTaskExecutor', function()
    it('has module level execute', function()
        local task = spy.new(function () end)

        SafeTaskExecutor.execute(task)

        assert.spy(task).was_called(1)
    end)

    it('needs a task to execute', function()
        local task = SafeTaskExecutor.new()

        assert.same({nil, 'not initialized'}, { task:execute() })
    end)

    it('returns success', function()
        local task = SafeTaskExecutor.new(function () return 'some value', 'some other value' end)

        assert.same({true, { 'some value', 'some other value' }}, { task:execute() })
    end)

    it('returns failure', function ()
        local task = SafeTaskExecutor.new(function () return error('some error') end)

        assert.same({false, nil, 'some error'}, { task:execute() })
    end)

end)
