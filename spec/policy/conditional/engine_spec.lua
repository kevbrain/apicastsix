local Engine = require('apicast.policy.conditional.engine')

describe('Engine', function()
  describe('.evaluate', function()
    it('evaluates "request_method"', function()
      stub(ngx.req, 'get_method', function () return 'GET' end)

      assert.equals('GET', Engine.evaluate('request_method'))
    end)

    it('evaluates "request_host"', function()
      ngx.var = { host = 'localhost' }

      assert.equals('localhost', Engine.evaluate('request_host'))
    end)

    it('evaluates "request_path"', function()
      ngx.var = { uri = '/some_path' }

      assert.equals('/some_path', Engine.evaluate('request_path'))
    end)

    it('evaluates "=="', function()
      stub(ngx.req, 'get_method', function () return 'GET' end)

      assert.is_true(Engine.evaluate('request_method == "GET"'))
      assert.is_false(Engine.evaluate('request_method == "POST"'))
    end)

    it('returns nil for expressions that cannot be evaluated', function()
      assert.is_nil(Engine.evaluate('request_method <> "GET"'))
    end)
  end)
end)
