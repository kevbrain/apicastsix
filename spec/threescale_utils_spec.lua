local _M = require('apicast.threescale_utils')

describe('3scale utils', function()
    describe('.error', function()
        it('returns concatenated error in timer phase', function()
            local get_phase = spy.on(ngx, 'get_phase', function() return 'timer' end)
            local error = _M.error('one', ' two', ' three')

            assert.spy(get_phase).was_called(1)

            assert.equal('one two three', error)
        end)
    end)
end)
