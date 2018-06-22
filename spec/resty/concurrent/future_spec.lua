local Future = require('resty.concurrent.future')
local TimerPoolExecutor = require('resty.concurrent.timer_pool_executor')

describe('Future', function()
   describe('.execute', function()
       it('returns future', function()
           local fun = spy.new(function() return 'some value' end)

           local future = Future.execute(fun)

           assert.same({ 'some value' }, future:value())
       end)

       it('works with timer #pool', function()
           local pool = TimerPoolExecutor.new()
           local fun = spy.new(function() return 'some value' end)

           assert(Future.execute(fun, { executor = pool }):value())
       end)
    end)

    describe(':execute', function()
        it('changes state', function()
            local spy = spy.new(function(...) return ... end)
            local task = Future.new(spy)

            assert(task:execute('value'))

            assert.equal('fulfilled', task.state)
            assert.spy(spy).was_called(1)
        end)

        it('captures the return value', function()
            local task = Future.new(function() return 'returned value' end)

            assert(task:execute())

            assert.same({ 'returned value' }, task:value())
        end)
    end)
end)
