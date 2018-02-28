local prometheus = require('nginx.prometheus')
local assert = assert
local dict = 'prometheus_metrics'

if ngx.shared[dict] then
  local init = prometheus.init(dict)

  local metrics = { }
  local __call = function(_, type, name, ...)
    local metric_name = assert(name, 'missing metric name')

    if not metrics[metric_name] then
      metrics[metric_name] = init[assert(type, 'missing metric type')](init, metric_name, ...)
    end

    return metrics[metric_name]
  end

  return setmetatable({ }, { __call = __call, __index = init })
else
  local noop = function() end
  return setmetatable({ collect = noop }, { __call = noop })
end
