local Request = require('apicast.policy.routing.request')

describe('Request', function()
  describe('.get_uri', function()
    it('returns the uri', function()
      ngx.var = { uri = 'test_path' }
      local request = Request.new()

      local uri = request:get_uri()

      assert.equals(ngx.var.uri, uri)
    end)

    it('caches the uri', function()
      ngx.var = { uri = 'test_path' }
      local request = Request.new()

      request:get_uri() -- cached after this
      local uri = request:get_uri()

      assert.equals(ngx.var.uri, uri)
    end)
  end)

  describe('.get_header', function()
    it('returns the value of the header', function()
      local header_name = 'test_header'
      local header_val = 'some_value'
      stub(ngx.req, 'get_headers',
        function() return { [header_name] = header_val }
      end)
      local request = Request.new()

      local res = request:get_header(header_name)

      assert.equals(header_val, res)
    end)

    it('caches the value of the header', function()
      local header_name = 'test_header'
      local header_val = 'some_value'
      stub(ngx.req, 'get_headers',
        function() return { [header_name] = header_val }
        end)
      local request = Request.new()

      request:get_header(header_name) -- cached after this
      local res = request:get_header(header_name)

      assert.stub(ngx.req.get_headers).was_called(1)
      assert.equals(header_val, res)
    end)

    it('returns nil when the header is not set', function()
      local header_name = 'test_header'
      stub(ngx.req, 'get_headers', function()
        return { [header_name] = nil }
      end)
      local request = Request.new()

      local res = request:get_header(header_name)

      assert.is_nil(res)
    end)
  end)

  describe('.get_uri_arg', function()
    it('returns the value of the query arg', function()
      local query_arg_name = 'test_query_arg'
      local query_arg_val = 'some_value'
      stub(ngx.req, 'get_uri_args', function()
        return { [query_arg_name] = query_arg_val }
      end)
      local request = Request.new()

      local res = request:get_uri_arg(query_arg_name)

      assert.equals(query_arg_val, res)
    end)

    it('caches the value of the query arg', function()
      local query_arg_name = 'test_query_arg'
      local query_arg_val = 'some_value'
      stub(ngx.req, 'get_uri_args', function()
        return { [query_arg_name] = query_arg_val }
      end)
      local request = Request.new()

      request:get_uri_arg(query_arg_name) -- cached after this
      local res = request:get_uri_arg(query_arg_name)

      assert.stub(ngx.req.get_uri_args).was_called(1)
      assert.equals(query_arg_val, res)
    end)

    it('returns nil when he query arg is not set', function()
      local query_arg_name = 'test_query_arg'
      stub(ngx.req, 'get_uri_args', function()
        return { [query_arg_name] = nil }
      end)
      local request = Request.new()

      local res = request:get_uri_arg(query_arg_name)

      assert.is_nil(res)
    end)
  end)

  describe('.get_validated_jwt', function()
    it('returns the jwt when it has been set', function()
      local request = Request.new()
      local test_jwt = { some_claim = 'some_val' }
      request:set_validated_jwt(test_jwt)

      assert.equals(test_jwt, request:get_validated_jwt())
    end)

    it('returns nil when the jwt has not been set', function()
      local request = Request.new()

      assert.is_nil(request:get_validated_jwt())
    end)
  end)
end)
