local QueryParams = require('apicast.policy.url_rewriting.query_params')

describe('QueryParams', function()
  before_each(function()
    stub(ngx.req, 'set_uri_args')
  end)

  describe('.push', function()
    describe('if the arg is not in the query', function()
      it('creates it with the given value', function()
        local params = QueryParams.new({ a = '1' })

        params:push('b', '2')

        local expected_args = { a = '1', b = '2' }
        assert.stub(ngx.req.set_uri_args).was_called_with(expected_args)
      end)
    end)

    describe('if the arg is in the query', function()
      describe('and it has a single value', function()
        it('adds a new value for it', function()
          local params = QueryParams.new({ a = '1' })

          params:push('a', '2')

          local expected_args = { a = { '1', '2' } }
          assert.stub(ngx.req.set_uri_args).was_called_with(expected_args)
        end)
      end)

      describe('and it is an array', function()
        it('adds a new value for it', function()
          local params = QueryParams.new({ a = { '1', '2' } })

          params:push('a', '3')

          local expected_args = { a = { '1', '2', '3' } }
          assert.stub(ngx.req.set_uri_args).was_called_with(expected_args)
        end)
      end)
    end)
  end)

  describe('.set', function()
    describe('if the arg is not in the query', function()
      it('creates it with the given value', function()
        local params = QueryParams.new({ a = '1' })

        params:set('b', '2')

        local expected_args = { a = '1', b = '2' }
        assert.stub(ngx.req.set_uri_args).was_called_with(expected_args)
      end)
    end)

    describe('if the arg is in the query', function()
      it('replaces its value with the given one', function()
        local params = QueryParams.new({ a = { '1', '2' } })

        params:set('a', '3')

        local expected_args = { a = '3' }
        assert.stub(ngx.req.set_uri_args).was_called_with(expected_args)
      end)
    end)

    describe('if value is empty', function()
      it('deletes the arg', function()
        local params = QueryParams.new({ a = '1' })

        params:set('a', '')

        assert.stub(ngx.req.set_uri_args).was_called_with({})
      end)
    end)
  end)

  describe('.add', function()
    describe('if the arg is not in the query', function()
      it('does nothing', function()
        local params = QueryParams.new({ a = '1' })

        params:add('b', '2')

        assert.stub(ngx.req.set_uri_args).was_not_called()
      end)
    end)

    describe('if the arg is in the query', function()
      describe('and it has a single value', function()
        it('adds a new value for it', function()
          local params = QueryParams.new({ a = '1' })

          params:add('a', '2')

          local expected_args = { a = { '1', '2' } }
          assert.stub(ngx.req.set_uri_args).was_called_with(expected_args)
        end)
      end)

      describe('and it is an array', function()
        it('adds a new value for it', function()
          local params = QueryParams.new({ a = { '1', '2' } })

          params:add('a', '3')

          local expected_args = { a = { '1', '2', '3' } }
          assert.stub(ngx.req.set_uri_args).was_called_with(expected_args)
        end)
      end)
    end)
  end)
end)
