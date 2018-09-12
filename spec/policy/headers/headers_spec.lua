local HeadersPolicy = require('apicast.policy.headers')
local ngx_variable = require 'apicast.policy.ngx_variable'

describe('Headers policy', function()
  before_each(function()
    -- avoid stubbing all the ngx.var.* and ngx.req.* in the available context
    stub(ngx_variable, 'available_context', function(context) return context end)
  end)

  -- Apply the operations to the same header in all the tests for simplicity
  local header = 'test_header'

  describe('.rewrite', function()
    local request_headers = 'request' -- rewrite() only modifies request headers

    local ngx_req_headers = {}

    before_each(function()
      -- ngx.req.get_headers and ngx.set_headers are not available in these tests
      -- so we need to mock them.
      -- Note: ngx.req_headers()['some_header'] can return a single value or a
      -- table.

      ngx_req_headers = {}
      stub(ngx.req, 'get_headers', function() return ngx_req_headers end)
      stub(ngx.req, 'set_header', function(name, value) ngx_req_headers[name] = value end)
    end)

    describe('the push operation', function()
      local push = 'push'

      it('creates the header with the given value when it is not set', function()
        local config = { [request_headers] = { { op = push, header = header, value = '1' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:rewrite()

        assert.same({ '1' }, ngx.req.get_headers()[header])
      end)

      it('adds the value to the list of values for that header when it is set', function()
        ngx_req_headers[header] = { '1', '2' }
        local config = { [request_headers] = { { op = push, header = header, value = '3' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:rewrite()

        assert.same({ '1', '2', '3' }, ngx.req.get_headers()[header])
      end)
    end)

    describe('the set operation', function()
      local set = 'set'

      it('creates the header when it is not set', function()
        local config = { [request_headers] = { { op = set, header = header, value = '1' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:rewrite()

        assert.same('1', ngx.req.get_headers()[header])
      end)

      it('replaces the value of a header when it is already set', function()
        ngx_req_headers[header] = '1'
        local config = { [request_headers] = { { op = set, header = header, value = '2' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:rewrite()

        assert.same('2', ngx.req.get_headers()[header])
      end)
    end)

    describe('the add operation', function()
      local add = 'add'

      it('does nothing when the header is not set', function()
        local config = { [request_headers] = { { op = add, header = header, value = '1' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:rewrite()

        assert.is_nil(ngx.req.get_headers()[header])
      end)

      it('adds the value to the list of values for that header when it is set', function()
        ngx_req_headers[header] = { '1', '2' }
        local config = { [request_headers] = { { op = add, header = header, value = '3' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:rewrite()

        assert.same({ '1', '2', '3' }, ngx.req.get_headers()[header])
      end)
    end)

    describe('when it has several operations in the config', function()
      it('executes all of them in the specified order', function()
        local config = {
          [request_headers] = {
            { op = 'push', header = header, value = '1' },
            { op = 'set', header = header, value = '2' },
            { op = 'add', header = header, value = '3' }
          }
        }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:rewrite()

        assert.same({ '2', '3' }, ngx.req.get_headers()[header])
      end)
    end)

    describe('when the type of the value is specified', function()
      describe("and it is 'liquid'", function()
        it('evaluates the value as liquid', function()
          local context = { var_in_context = 'some_value' }

          local config = {
            [request_headers] = {
              {
                op = 'push',
                header = header,
                value = '{{ var_in_context }}',
                value_type = 'liquid'
              }
            }
          }

          local headers_policy = HeadersPolicy.new(config)

          headers_policy:rewrite(context)

          assert.same({ context.var_in_context }, ngx.req.get_headers()[header])
        end)
      end)

      describe("and it is 'plain'", function()
        it('evaluates the value as plain text', function()
          local context = { var_in_context = 'some_value' }
          local value = '{{ var_in_context }}'

          local config = {
            [request_headers] = {
              {
                op = 'push',
                header = header,
                value = value,
                value_type = 'plain'
              }
            }
          }

          local headers_policy = HeadersPolicy.new(config)

          headers_policy:rewrite(context)

          assert.same({ value }, ngx.req.get_headers()[header])
        end)
      end)
    end)
  end)

  describe('.header_filter', function()
    local response_headers = 'response' -- header_filter() only modifies resp headers

    before_each(function()
      -- Replace original ngx.header. Openresty does not allow to modify it when
      -- running busted tests.
      ngx.header = {}
    end)

    describe('the push operation', function()
      local push = 'push'

      it('creates the header with the given value when it is not set', function()
        local config = { [response_headers] = { { op = push, header = header, value = '1' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:header_filter()

        assert.same({ '1' }, ngx.header[header])
      end)

      it('adds the value to the list of values for that header when its set', function()
        ngx.header[header] = { '1', '2' }
        local config = { [response_headers] = { { op = push, header = header, value = '3' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:header_filter()

        assert.same({ '1', '2', '3' }, ngx.header[header])
      end)
    end)

    describe('the set operation', function()
      local set = 'set'

      it('creates the header when it is not set', function()
        local config = { [response_headers] = { { op = set, header = header, value = '1' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:header_filter()

        assert.same('1', ngx.header[header])
      end)

      it('replaces the value of a header when it is already set', function()
        ngx.header[header] = '1'
        local config = { [response_headers] = { { op = set, header = header, value = '2' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:header_filter()

        assert.same('2', ngx.header[header])
      end)
    end)

    describe('the add operation', function()
      local add = 'add'

      it('does nothing when the header is not set', function()
        local config = { [response_headers] = { { op = add, header = header, value = '1' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:header_filter()

        assert.is_nil(ngx.header[header])
      end)

      it('adds the value to the list of values for that header when its set', function()
        ngx.header[header] = { '1', '2' }
        local config = { [response_headers] = { { op = add, header = header, value = '3' } } }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:header_filter()

        assert.same({ '1', '2', '3' }, ngx.header[header])
      end)
    end)

    describe('when it has several operations in the config', function()
      it('executes all of them in the specified order', function()
        local config = {
          [response_headers] = {
            { op = 'push', header = header, value = '1' },
            { op = 'set', header = header, value = '2' },
            { op = 'add', header = header, value = '3' }
          }
        }
        local headers_policy = HeadersPolicy.new(config)

        headers_policy:header_filter()

        assert.same({ '2', '3' }, ngx.header[header])
      end)
    end)

    describe('when the type of the value is specified', function()
      describe("and it is 'liquid'", function()
        it('evaluates the value as liquid', function()
          local context = { var_in_context = 'some_value' }

          local config = {
            [response_headers] = {
              {
                op = 'push',
                header = header,
                value = '{{ var_in_context }}',
                value_type = 'liquid'
              }
            }
          }

          local headers_policy = HeadersPolicy.new(config)

          headers_policy:header_filter(context)

          assert.same({ context.var_in_context }, ngx.header[header])
        end)
      end)

      describe("and it is 'plain'", function()
        it('evaluates the value as plain text', function()
          local context = { var_in_context = 'some_value' }
          local value = '{{ var_in_context }}'

          local config = {
            [response_headers] = {
              {
                op = 'push',
                header = header,
                value = value,
                value_type = 'plain'
              }
            }
          }

          local headers_policy = HeadersPolicy.new(config)

          headers_policy:header_filter(context)

          assert.same({ value }, ngx.header[header])
        end)
      end)
    end)
  end)
end)
