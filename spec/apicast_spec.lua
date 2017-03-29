local _M = require 'apicast'

describe('APIcast module', function()

  it('has a name', function()
    assert.truthy(_M._NAME)
  end)

  it('has a version', function()
    assert.truthy(_M._VERSION)
  end)

  describe(':access', function()

    local apicast

    before_each(function()
      apicast = _M.new()
      ngx.ctx.proxy = {}
    end)

    it('triggers post action when access phase succeeds', function()
      ngx.var = { original_request_id = 'foobar' }

      stub(ngx.ctx.proxy, 'call', function()
        return function() return 'ok' end
      end)

      stub(ngx.ctx.proxy, 'post_action', function()
        return 'post_ok'
      end)

      local ok, err = apicast:access()

      assert.same('ok', ok)
      assert.falsy(err)

      assert.same('post_ok', apicast:post_action())
    end)

    it('skips post action when access phase not executed', function()
      stub(ngx.ctx.proxy, 'call', function()
        -- return nothing for example
      end)

      local ok, err = apicast:access()

      assert.falsy(ok)
      assert.falsy(err)

      ngx.ctx.proxy = nil -- in post_action the ctx is not shared
      ngx.var = { original_request_id = 'foobar' }

      assert.equal(nil, apicast:post_action())
    end)
  end)
end)
