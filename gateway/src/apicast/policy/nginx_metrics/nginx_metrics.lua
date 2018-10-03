local _M = require('apicast.policy').new('Metrics')

local resty_env = require('resty.env')
local errlog = require('ngx.errlog')
local prometheus = require('apicast.prometheus')
local metrics_updater = require('apicast.metrics.updater')
local tonumber = tonumber
local select = select
local find = string.find
local pairs = pairs

local upstream_metrics = require('apicast.metrics.upstream')

local new = _M.new

local log_levels_list = {
  'emerg',
  'alert',
  'crit',
  'error',
  'warn',
  'notice',
  'info',
  'debug',
}

local log_level_env = 'NGINX_METRICS_LOG_LEVEL'
local max_logs_env = 'NGINX_METRICS_MAX_LOGS'

local log_level_default = 'error'
local max_logs_default = 100

local function find_i(t, value)
  for i=1, #t do
    if t[i] == value then return i end
  end
end

local empty = {}

local function get_logs(max)
  return errlog.get_logs(max) or empty
end

local function filter_level()
  local level = resty_env.value(log_level_env) or log_level_default

  local level_index = find_i(log_levels_list, level)

  if not level_index then
    ngx.log(ngx.WARN, _M._NAME, ': invalid level: ', level, ' using error instead')
    level_index = find_i(log_levels_list, 'error')
  end

  return level_index
end

function _M.new(configuration)
  local m = new()

  local config = configuration or empty

  -- how many logs to take in one iteration
  m.max_logs = tonumber(config.max_logs) or
               resty_env.value(max_logs_env) or
               max_logs_default

  return m
end

local logs_metric = prometheus('counter', 'nginx_error_log', "Items in nginx error log", {'level'})
local http_connections_metric =  prometheus('gauge', 'nginx_http_connections', 'Number of HTTP connections', {'state'})
local shdict_capacity_metric = prometheus('gauge', 'openresty_shdict_capacity', 'OpenResty shared dictionary capacity', {'dict'})
local shdict_free_space_metric = prometheus('gauge', 'openresty_shdict_free_space', 'OpenResty shared dictionary free space', {'dict'})

function _M.init()
  errlog.set_filter_level(filter_level())

  get_logs(100) -- to throw them away after setting the filter level (and get rid of debug ones)

  for name,dict in pairs(ngx.shared) do
    metrics_updater.set(shdict_capacity_metric, dict:capacity(), name)
  end
end

function _M:metrics()
  local logs = get_logs(self.max_logs)

  for i = 1, #logs, 3 do
    metrics_updater.inc(logs_metric, log_levels_list[logs[i]] or 'unknown')
  end

  local response = ngx.location.capture("/nginx_status")

  if response.status == 200 then
    local accepted, handled, total = select(3, find(response.body, [[accepts handled requests%s+(%d+) (%d+) (%d+)]]))
    local var = ngx.var

    metrics_updater.set(http_connections_metric, var.connections_reading, 'reading')
    metrics_updater.set(http_connections_metric, var.connections_waiting, 'waiting')
    metrics_updater.set(http_connections_metric, var.connections_writing, 'writing')
    metrics_updater.set(http_connections_metric, var.connections_active, 'active')
    metrics_updater.set(http_connections_metric, accepted, 'accepted')
    metrics_updater.set(http_connections_metric, handled, 'handled')
    metrics_updater.set(http_connections_metric, total, 'total')
  else
    prometheus:log_error('Could not get status from nginx')
  end

  for name,dict in pairs(ngx.shared) do
    metrics_updater.set(shdict_free_space_metric, dict:free_space(), name)
  end
end

function _M.log()
  upstream_metrics.report(ngx.var.upstream_status, ngx.var.upstream_response_time)
end

return _M
