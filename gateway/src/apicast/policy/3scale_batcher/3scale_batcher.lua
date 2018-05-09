local backend_client = require('apicast.backend_client')
local AuthsCache = require('auths_cache')
local ReportsBatcher = require('reports_batcher')
local policy = require('apicast.policy')
local errors = require('apicast.errors')
local reporter = require('reporter')
local http_ng_resty = require('resty.http_ng.backend.resty')
local semaphore = require('ngx.semaphore')

local ipairs = ipairs

local default_auths_ttl = 10
local default_batch_reports_seconds = 10

local _M = policy.new('Caching policy')

local new = _M.new

function _M.new(config)
  local self = new(config)

  local auths_ttl = config.auths_ttl or default_auths_ttl
  self.auths_cache = AuthsCache.new(ngx.shared.cached_auths, auths_ttl)

  self.reports_batcher = ReportsBatcher.new(
    ngx.shared.batched_reports, 'batched_reports_locks')

  self.batch_reports_seconds = config.batch_reports_seconds or
                               default_batch_reports_seconds

  self.report_timer_on = false

  -- Semaphore used to ensure that only one timer is started per worker.
  local semaphore_report_timer, err = semaphore.new(1)
  if not semaphore_report_timer then
    ngx.log(ngx.ERR, "Create semaphore failed: ", err)
  end
  self.semaphore_report_timer = semaphore_report_timer

  return self
end

-- TODO: More policies are using this method. Move it to backend_client to
-- avoid duplicating code.
-- Converts a usage to the format expected by the 3scale backend client.
local function format_usage(usage)
  local res = {}

  local usage_metrics = usage.metrics
  local usage_deltas = usage.deltas

  for _, metric in ipairs(usage_metrics) do
    local delta = usage_deltas[metric]
    res['usage[' .. metric .. ']'] = delta
  end

  return res
end

local function set_flags_to_avoid_auths_in_apicast(context)
  context.skip_apicast_access = true
  context.skip_apicast_post_action = true
end

local function report(_, service_id, backend, reports_batcher)
  local reports = reports_batcher:get_all(service_id)

  -- TODO: verify if we should limit the number of reports sent in a sigle req
  reporter.report(reports, service_id, backend, reports_batcher)
end

-- This starts a timer on each worker.
-- Starting a timer on each worker means that there will be more calls to
-- 3scale backend, and the config param 'batch_report_seconds' becomes
-- more confusing because the reporting frequency will be affected by the
-- number of APIcast workers.
-- If we started a timer just on one of the workers, it could die, and then,
-- there would not be any reporting.
local function ensure_report_timer_on(self, service_id, backend)
  local check_timer = self.semaphore_report_timer:wait(0)

  if check_timer then
    if not self.report_timer_on then
      ngx.timer.every(self.batch_reports_seconds, report,
        service_id, backend, self.reports_batcher)

      self.report_timer_on = true
    end

    self.semaphore_report_timer:post()
  end
end

local function rejection_reason_from_headers(response_headers)
  return response_headers and response_headers['3scale-rejection-reason']
end

local function error(service, rejection_reason)
  if rejection_reason == 'limits_exceeded' then
    return errors.limits_exceeded(service)
  else
    return errors.authorization_failed(service)
  end
end

-- Note: when an entry in the cache expires, there might be several requests
-- with those credentials and all of them will call auth() on backend with the
-- same parameters until the auth status is cached again. In the future, we
-- might want to introduce a mechanism to avoid this and reduce the number of
-- calls to backend.
function _M:access(context)
  local backend = backend_client:new(context.service, http_ng_resty)
  local usage = context.usage
  local service = context.service
  local service_id = service.id
  local credentials = context.credentials

  ensure_report_timer_on(self, service_id, backend)

  local cached_auth = self.auths_cache:get(service_id, credentials, usage)

  if not cached_auth then
    local formatted_usage = format_usage(usage)
    local backend_res = backend:authorize(formatted_usage, credentials)
    local backend_status = backend_res.status

    if backend_status == 200 then
      self.auths_cache:set(service_id, credentials, usage, 200)
      local to_batch = { service_id = service_id, credentials = credentials, usage = usage }
      self.reports_batcher:add(to_batch.service_id, to_batch.credentials, to_batch.usage)
    elseif backend_status >= 400 and backend_status < 500 then
      local rejection_reason = rejection_reason_from_headers(backend_res.headers)
      self.auths_cache:set(service_id, credentials, usage, backend_status, rejection_reason)
      return error(service, rejection_reason)
    else
      return error(service)
    end
  else
    if cached_auth.status == 200 then
      local to_batch = { service_id = service_id, credentials = credentials, usage = usage }
      self.reports_batcher:add(to_batch.service_id, to_batch.credentials, to_batch.usage)
    else
      return error(service, cached_auth.rejection_reason)
    end
  end

  set_flags_to_avoid_auths_in_apicast(context)
end

return _M
