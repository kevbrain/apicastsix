local tonumber = tonumber

local _M = {}

local function metric_op(op, metric, value, label)
  local metric_labels = {}
  if not metric then return end
  metric_labels[1] = label
  metric[op](metric, tonumber(value) or 0, metric_labels)
end

function _M.set(metric, value, label)
  return metric_op('set', metric, value, label)
end

function _M.inc(metric, label)
  return metric_op('inc', metric, 1, label)
end

return _M
