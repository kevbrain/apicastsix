local EchoPolicy = require('apicast.policy.echo')

describe('Echo policy', function()
  describe('.rewrite', function()
    describe('when configured with exit=request', function()
      it('stops processing the request and returns with the configured status', function()
        local ngx_exit_spy = spy.on(ngx, 'exit')
        local status = 200
        local echo = EchoPolicy.new({ status = status, exit = 'request' })

        echo:rewrite()

        assert.spy(ngx_exit_spy).was_called_with(status)
      end)
    end)

    describe('when configured with exit=phase', function()
      it('skips the current phase', function()
        local ngx_exit_spy = spy.on(ngx, 'exit')
        local echo = EchoPolicy.new({ status = 200, exit = 'phase' })

        echo:rewrite()

        assert.spy(ngx_exit_spy).was_called_with(0)
      end)
    end)
  end)
end)
