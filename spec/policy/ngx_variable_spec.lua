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

      stub(ngx.req, 'get_method', function()
        return 'GET'
      end)

      local context = ngx_variable.available_context()

      assert.equals('some_val', context.headers['some_header'])
      assert.equals('GET', context.http_method)
    end)

    it('gives precedence to what is exposed in "ngx_variable"', function()
      local headers_in_ngx_variable = { some_header = 'some_val' }
      local headers_in_context = { some_header = 'different_val' }

      stub(ngx.req, 'get_headers', function()
        return headers_in_ngx_variable
      end)

      stub(ngx.req, 'get_method', function()
        return 'GET'
      end)

      local policies_context = { headers = headers_in_context }

      local liquid_context = ngx_variable.available_context(policies_context)

      assert.equals(headers_in_ngx_variable.some_header,
                    liquid_context.headers.some_header)
    end)
  end)
end)
