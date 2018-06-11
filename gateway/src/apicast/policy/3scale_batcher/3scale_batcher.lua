local backend_client = require('apicast.backend_client')
local AuthsCache = require('auths_cache')
local ReportsBatcher = require('reports_batcher')
local keys_helper = require('keys_helper')
local policy = require('apicast.policy')
local errors = require('apicast.errors')
local reporter = require('reporter')
local Transaction = require('transaction')
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

  self.batch_reports_seconds = config.batch_report_seconds or
                               default_batch_reports_seconds

  self.report_timer_on = false

  -- Semaphore used to ensure that only one timer is started per worker.
  local semaphore_report_timer, err = semaphore.new(1)
  if not semaphore_report_timer then
    ngx.log(ngx.ERR, "Create semaphore failed: ", err)
  end
  self.semaphore_report_timer = semaphore_report_timer

  -- Cache for authorizations to be used in the event of a 3scale backend
  -- downtime.
  -- This cache allows us to use this policy in combination with the caching
  -- one.
  self.backend_downtime_cache = ngx.shared.api_keys

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

  if reports then
    ngx.log(ngx.DEBUG, '3scale batcher report timer got ', #reports, ' reports')
  end

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
      ngx.log(ngx.DEBUG, 'scheduled 3scale batcher report timer every ',
                         self.batch_reports_seconds, ' seconds')
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

local function update_downtime_cache(cache, transaction, backend_status, cache_handler)
  local key = keys_helper.key_for_cached_auth(transaction)
  cache_handler(cache, key, backend_status)
end

local function handle_backend_ok(self, transaction, cache_handler)
  if cache_handler then
    update_downtime_cache(self.backend_downtime_cache, transaction, 200, cache_handler)
  end

  self.auths_cache:set(transaction, 200)
  self.reports_batcher:add(transaction)
end

local function handle_backend_denied(self, service, transaction, status, headers, cache_handler)
  if cache_handler then
    update_downtime_cache(self.backend_downtime_cache, transaction, status, cache_handler)
  end

  local rejection_reason = rejection_reason_from_headers(headers)
  self.auths_cache:set(transaction, status, rejection_reason)
  return error(service, rejection_reason)
end

local function handle_backend_error(self, service, transaction, cache_handler)
  local cached = cache_handler and self.backend_downtime_cache:get(transaction)

  if cached == 200 then
    self.reports_batcher:add(transaction)
  else
    -- The caching policy does not store the rejection reason, so we can only
    -- return a generic error.
    return error(service)
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
  local transaction = Transaction.new(service_id, credentials, usage)

  ensure_report_timer_on(self, service_id, backend)

  local cached_auth = self.auths_cache:get(transaction)

  if not cached_auth then
    local formatted_usage = format_usage(usage)
    local backend_res = backend:authorize(formatted_usage, credentials)
    local backend_status = backend_res.status
    local cache_handler = context.cache_handler -- Set by Caching policy

    if backend_status == 200 then
      handle_backend_ok(self, transaction, cache_handler)
    elseif backend_status >= 400 and backend_status < 500 then
      handle_backend_denied(
        self, service, transaction, backend_status, backend_res.headers, cache_handler)
    else
      handle_backend_error(self, service, transaction, cache_handler)
    end
  else
    if cached_auth.status == 200 then
      self.reports_batcher:add(transaction)
    else
      return error(service, cached_auth.rejection_reason)
    end
  end

  set_flags_to_avoid_auths_in_apicast(context)
end

return _M
