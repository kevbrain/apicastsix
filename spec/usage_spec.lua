local Usage = require('apicast.usage')

describe('usage', function()
  describe('.add', function()
    describe('when the metric is already present in the usage', function()
      it('adds the given value to the existing one', function()
        local usage = Usage.new()

        usage:add('hits', 1)
        assert.same({ hits = 1 }, usage.deltas )

        usage:add('hits', 1)
        assert.same({ hits = 2 }, usage.deltas)
      end)
    end)

    describe('when the metric is not in the usage', function()
      it('adds it with the given value', function()
        local usage = Usage.new()
        usage:add('hits', 1)

        assert.same({ hits = 1 }, usage.deltas)
      end)
    end)
  end)

  describe('.merge', function()
    describe('when a metric appears in both usages', function()
      it('mutates self adding the deltas', function()
        local a_usage = Usage.new()
        a_usage:add('a', 1)
        a_usage:add('b', 1)

        local another_usage = Usage.new()
        another_usage:add('a', 2)
        another_usage:add('b', 2)

        a_usage:merge(another_usage)

        assert.same({ a = 3, b = 3 }, a_usage.deltas)
      end)
    end)

    describe('when a metric of the given usage is not in self', function()
      it('adds the metric in self', function()
        local a_usage = Usage.new()
        a_usage:add('a', 1)

        local another_usage = Usage.new()
        another_usage:add('b', 1)

        a_usage:merge(another_usage)

        assert.same({ a = 1, b = 1 }, a_usage.deltas)
      end)
    end)

    describe('when the other usage does not contain any deltas', function()
      it('leaves self unchanged', function()
        local a_usage = Usage.new()
        a_usage:add('a', 1)

        a_usage:merge(Usage.new())

        assert.same({ a = 1 }, a_usage.deltas)
      end)
    end)
  end)

  describe('.metrics', function()
    it('returns a table without duplicates with all the metrics that have a delta', function()
      local usage = Usage.new()
      usage:add('hits', 1)
      usage:add('hits', 1) -- try adding a metric that already exists
      usage:add('some_metric', 1)

      -- Try merging with a usage with the same metrics.
      local another_usage = Usage.new()
      another_usage:add('hits', 1)
      another_usage:add('some_metric', 1)
      usage:merge(another_usage)

      local metrics = usage.metrics

      -- The method does not guarantee any order in the result
      assert.is_true((metrics[1] == 'hits' and metrics[2] == 'some_metric') or
          (metrics[1] == 'some_metric' and metrics[2] == 'hits'))
    end)
  end)
end)
