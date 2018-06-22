local ImmediateExecutor = require('resty.concurrent.immediate_executor')

describe('ImmediateExecutor', function()
    describe(':post', function()
        it('executes in the same coroutine', function()
            local fun = coroutine.running

            assert.equal(fun(), ImmediateExecutor:post(fun))
        end)
    end)
end)
