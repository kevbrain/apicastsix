local resolver_cache = require 'resty.resolver.cache'

describe('resty.resolver.cache', function()

  local answers = { {
    class = 1,
    cname = "elb.example.com",
    name = "www.example.com",
    section = 1,
    ttl = 599,
    type = 5
  }, {
    class = 1,
    cname = "example.us-east-1.elb.amazonaws.com",
    name = "elb.example.com",
    section = 1,
    ttl = 299,
    type = 5
  }, {
    address = "54.221.208.116",
    class = 1,
    name = "example.us-east-1.elb.amazonaws.com",
    section = 1,
    ttl = 59,
    type = 1
  }, {
    address = "54.221.221.16",
    class = 1,
    name = "example.us-east-1.elb.amazonaws.com",
    section = 1,
    ttl = 59,
    type = 1
  } }

  describe('.save', function()

    local c = resolver_cache.new()

    it('returns compacted answers', function()
      local keys = {}

      for _,v in ipairs(c:save(answers)) do
        table.insert(keys, v.name)
      end

      assert.same(
        {'www.example.com',  'elb.example.com', 'example.us-east-1.elb.amazonaws.com' },
        keys)
    end)

    it('stores the result', function()
      c.store = spy.new(c.store)

      c:save(answers)

      assert.spy(c.store).was.called(3) -- TODO: proper called_with(args)
    end)
  end)

  describe('.store', function()
    local cache = {}
    local c = resolver_cache.new(cache)

    it('writes to the cache', function()
      local record = { 'someting' }
      local answer = { record, ttl = 60, name = 'foo.example.com' }
      c.cache.set = spy.new(function(_, key, value, ttl)
        assert.same('foo.example.com', key)
        assert.same(answer, value)
        assert.same(60, ttl)
      end)

      c:store(answer)

      assert.spy(c.cache.set).was.called(1)
    end)

    it('works with -1 ttl', function()
      local answer = { { 'something' }, ttl = -1, name = 'foo.example.com' }

      c.cache.set = spy.new(function(_, key, value, ttl)
        assert.same('foo.example.com', key)
        assert.same(answer, value)
        assert.same(nil, ttl)
      end)

      c:store(answer)

      assert.spy(c.cache.set).was.called(1)
    end)
  end)

  describe('.get', function()
    local c = resolver_cache.new()

    it('returns answers', function()
      c:save(answers)

      local ans = c:get('www.example.com')

      assert.same({ "54.221.208.116", "54.221.221.16" }, ans.addresses)
    end)
  end)

end)
