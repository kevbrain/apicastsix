local Event = require('resty.concurrent.event')

local yield = function () ngx.sleep(0) end

describe('Event', function()
    local threads = {}

    local spawn = function(fun) -- helper function to track all threads and kill them between tests
        local thread = ngx.thread.spawn(assert(fun))
        table.insert(threads, thread)
        return thread
    end

    after_each(function()
        for i,thread in ipairs(threads) do
            ngx.thread.kill(thread)
            threads[i] = nil
        end
    end)

    it('will not wait then already set', function()
        local event = Event.new()

        assert(event:set())
        assert(event:wait())
    end)


    describe('works with multiple threads', function()
        it('notifies all threads', function()
            local event = Event.new()
            local success = spy.new(function () end)

            local w1 = spawn(function () assert(event:wait()); success() end)
            local w2 = spawn(function () assert(event:wait()); success() end)

            event:set()

            assert(ngx.thread.wait(w1))
            assert(ngx.thread.wait(w2))

            assert.spy(success).was_called(2)
        end)

        it('can be published from a thread', function()
            local event = Event.new()

            local set = spawn(function () assert(event:set()) end)

            assert(event:wait())
            assert(ngx.thread.wait(set))
        end)

        it('can be published and waited in different threads', function()
            local event = Event.new()
            local success = spy.new(function () end)

            local w1 = spawn(function () assert(event:wait()); yield(); success() end)
            local w2 = spawn(function () yield(); assert(event:wait()); success() end)

            local set = spawn(function () yield(); assert(event:set()) end)
            assert(ngx.thread.wait(set))

            assert(ngx.thread.wait(w1))
            assert(ngx.thread.wait(w2))

            assert.spy(success).was_called(2)
        end)
    end)
end)
