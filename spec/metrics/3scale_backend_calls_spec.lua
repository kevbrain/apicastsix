describe('backend calls metrics', function()
  describe('report', function()
    local threescale_backend_calls_metrics
    local test_counter = { inc = function() end }

    before_each(function()
      stub(test_counter, 'inc')
      local Prometheus = require('apicast.prometheus')
      getmetatable(Prometheus).__call = function(_, type)
        if type == 'counter' then
          return test_counter
        end
      end

      package.loaded['apicast.metrics.3scale_backend_calls'] = nil
      threescale_backend_calls_metrics = require('apicast.metrics.3scale_backend_calls')
    end)

    after_each(function()
      package.loaded['apicast.prometheus'] = nil
      require('apicast.prometheus')

      package.loaded['apicast.metrics.3scale_backend_calls'] = nil
      require('apicast.metrics.3scale_backend_calls')
    end)

    it('increases the counter for type of request and status code (2xx, 4xx, etc.)', function()
      threescale_backend_calls_metrics.report('authrep', 200)

      assert.stub(test_counter.inc).was_called_with(
        test_counter, 1, { 'authrep', '2xx' })
    end)

    it('sets the status code to "invalid_status" when it is nil', function()
      threescale_backend_calls_metrics.report('auth', nil)

      assert.stub(test_counter.inc).was_called_with(
        test_counter, 1, { 'auth', 'invalid_status' })
    end)

    it('set the status code to "invalid_status" when it is empty', function()
      threescale_backend_calls_metrics.report('auth', '')

      assert.stub(test_counter.inc).was_called_with(
        test_counter, 1, { 'auth', 'invalid_status' })
    end)

    it('sets the status code to "invalid_status" when it is 0', function()
      threescale_backend_calls_metrics.report('auth', 0)

      assert.stub(test_counter.inc).was_called_with(
        test_counter, 1, { 'auth', 'invalid_status' })
    end)
  end)
end)
