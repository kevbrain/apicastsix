local keys_helper = require('apicast.policy.3scale_batcher.keys_helper')

local setmetatable = setmetatable
local ipairs = ipairs
local insert = table.insert
local resty_lock = require 'resty.lock'

local _M = {}

local mt = { __index = _M }

local lock_timeout = 10
local lock_options = { timeout = lock_timeout }

-- Note: storage needs to implement shdict interface.
function _M.new(storage, lock_shdict_name)
  local self = setmetatable({}, mt)
  self.storage = storage
  self.lock_shdict_name = lock_shdict_name
  return self
end

-- Note: When the lock cannot be acquired, the report will be lost.
-- The timeout is high, that means that if it could not be acquired, there's
-- probably a problem in the system.
-- TODO: Find a solution for this.
function _M:add(service_id, credentials, usage)
  local deltas = usage.deltas

  local lock, new_lock_err = resty_lock:new(self.lock_shdict_name, lock_options)
  if not lock then
    ngx.log(ngx.ERR, 'failed to create lock: ', new_lock_err)
    return
  end

  local elapsed, lock_err = lock:lock(service_id)
  if not elapsed then
    ngx.log("failed to acquire the lock: ", lock_err)
    return
  end

  for _, metric in ipairs(usage.metrics) do
    local key = keys_helper.key_for_batched_report(service_id, credentials, metric)
    self.storage:incr(key, deltas[metric], 0)
  end

  local ok, unlock_err = lock:unlock()
  if not ok then
    ngx.log(ngx.ERR, 'failed to unlock: ', unlock_err)
    return
  end
end

function _M:get_all(service_id)
  local cached_reports = {}

  local cached_report_keys = self.storage:get_keys()

  local lock, new_lock_err = resty_lock:new(self.lock_shdict_name, lock_options)
  if not lock then
    ngx.log(ngx.ERR, 'failed to create lock: ', new_lock_err)
    return {}
  end

  local elapsed, lock_err = lock:lock(service_id)
  if not elapsed then
    ngx.log(ngx.ERR, "failed to acquire the lock: ", lock_err)
    return {}
  end

  for _, key in ipairs(cached_report_keys) do
    local value = self.storage:get(key)

    local report = keys_helper.report_from_key_batched_report(key, value)

    if value and value > 0 and report.service_id == service_id then
      insert(cached_reports, report)
      self.storage:delete(key)
    end
  end

  local ok, unlock_err = lock:unlock()
  if not ok then
    ngx.log(ngx.ERR, 'failed to unlock: ', unlock_err)
    return
  end

  return cached_reports
end

return _M
