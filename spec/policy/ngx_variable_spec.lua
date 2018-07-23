local ngx_variable = require('apicast.policy.ngx_variable')

describe('ngx_variable', function()
  describe('.available_context', function()
    before_each(function()
      ngx.var = {}
    end)

    it('exposes request headers in the "headers" table', function()
      stub(ngx.req, 'get_headers', function()
        return { some_header = 'some_val' }
      end)

      local context = ngx_variable.available_context()

      assert('some_val', context.headers['some_header'])
    end)
  end)
end)
