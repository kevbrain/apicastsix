
describe('prometheus', function()
  before_each(function() package.loaded['apicast.prometheus'] = nil end)

  describe('shared dictionary is missing', function()
    before_each(function() ngx.shared.prometheus_metrics = nil end)

    it('can be called', function()
      assert.is_nil(require('apicast.prometheus')())
    end)

    it('can be collected', function()
      assert.is_nil(require('apicast.prometheus'):collect())
    end)
  end)

  describe('shared dictionary is there', function()
    before_each(function()
      ngx.shared.prometheus_metrics = {
        set = function() end,
        get_keys = function() return {} end
      }
    end)

    local prometheus
    local Prometheus

    before_each(function()
      prometheus = assert(require('apicast.prometheus'))
      Prometheus = getmetatable(prometheus).__index
    end)

    for _,metric_type in pairs{ 'counter', 'gauge', 'histogram' } do
      describe(metric_type, function()
        it('can be called', function()
          stub(Prometheus, metric_type)

          prometheus(metric_type, 'some_metric')

          assert.stub(Prometheus[metric_type]).was.called_with(Prometheus, 'some_metric')
        end)
      end)
    end


    it('can be collected', function()
      ngx.header = { }
      assert.is_nil(require('apicast.prometheus'):collect())
    end)
  end)

end)
