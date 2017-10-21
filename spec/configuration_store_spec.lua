local configuration = require 'configuration_store'

describe('Configuration Store', function()

  describe('.store', function()
    it('stores configuration', function()
      local store = configuration.new()
      local service = { id = '42', hosts = { 'example.com' } }

      store:store({services = { service }})

      assert.equal(service, store:find_by_id('42'))
    end)
  end)

  describe('.find_by_id', function()
    it('returns an error when not initialized', function()
      local res, err = configuration:find_by_id()

      assert.falsy(res)
      assert.equal('not initialized', err)
    end)

    it('finds service by id', function()
      local store = configuration.new()
      local service = { id = '42' }

      store:add(service)

      assert.same(service, store:find_by_id('42'))
    end)

    it('does not seach by host', function()
      local store = configuration.new()
      local service = { id = '42', hosts = { 'example.com' } }

      store:add(service)

      assert.is_nil(store:find_by_id('example.com'))
    end)

    it('overrides previous values', function()
      local store = configuration.new()
      local first = { id = '42', hosts = { 'first.example.com' } }
      local second = { id = '42', hosts = { 'second.example.com' } }

      store:add(first)
      assert.equal(first, store:find_by_id('42'))

      store:add(second)
      assert.equal(second, store:find_by_id('42'))
    end)
  end)

  describe('.find_by_host', function()
    it('returns an error when not initialized', function()
      local res, err = configuration:find_by_host()

      assert.falsy(res)
      assert.equal('not initialized', err)
    end)

    it('returns stored services by host', function()
      local store = configuration.new()
      local service =  { id = '42', hosts = { 'example.com' } }

      store:add(service)

      assert.same({ service }, store:find_by_host('example.com'))
    end)

    it('works with multiple hosts', function()
      local store = configuration.new()
      local service =  { id = '21', hosts = { 'example.com', 'localhost' } }

      store:add(service)

      assert.same({ service }, store:find_by_host('example.com'))
      assert.same({ service }, store:find_by_host('localhost'))
    end)

    it('does not search by id', function()
      local store = configuration.new()
      local service = { id = '42' }

      store:add(service)

      assert.same({}, store:find_by_host('42'))
    end)

    it('returns empty array on no results', function()
      local store = configuration.new()

      assert.same({ }, store:find_by_host('unknown'))
    end)

    it('returns stale records by default', function()
      local store = configuration.new()
      local service =  { id = '21', hosts = { 'example.com', 'localhost' } }

      store:add(service, -1)

      assert.same({ service }, store:find_by_host('example.com'))
    end)

    it('does not return stale records when disabled', function()
      local store = configuration.new()
      local service =  { id = '21', hosts = { 'example.com', 'localhost' } }

      store:add(service, -1)

      assert.same({ }, store:find_by_host('example.com', false))
    end)

    it('normalizes hosts to lowercase', function()
      local store = configuration.new()
      local service =  { id = '21', hosts = { 'EXAMPLE.com' } }

      store:add(service)

      assert.same({ service }, store:find_by_host('example.com'))
    end)
  end)

  describe('.reset', function()
    describe('when not initialized', function()
      it('returns an error', function()
        local res, err = configuration:reset()

        assert.falsy(res)
        assert.equal('not initialized', err)
      end)
    end)

    describe('when configured', function()
      local store

      before_each(function()
        store = configuration.new()
      end)

      it('deletes stored hosts', function()
        store.cache['example.com'] = { { '42'} }

        store:reset()

        assert.same({}, store.cache.hasht)
      end)

      it('deletes all services', function()
        store.services['42'] = {}

        store:reset()

        assert.same({}, store.services.hasht)
      end)

      it('sets configured flag', function()
        store.configured = true

        store:reset()

        assert.falsy(store.configured)
      end)
    end)
  end)

  describe('.all', function()
    it('returns an error when not initialized', function()
      local res, err = configuration:all()

      assert.falsy(res)
      assert.equal('not initialized', err)
    end)

    it('returns all services', function()
      local store = configuration.new()

      local service = { id = '42' }
      store:add(service)

      assert.same({ service }, store:all())
    end)
  end)
end)
