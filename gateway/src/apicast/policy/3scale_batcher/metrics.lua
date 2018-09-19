local prometheus = require('apicast.prometheus')

local _M = {}

local auth_cache_hits = prometheus(
  'counter',
  'batching_policy_auths_cache_hits',
  'Hits in the auths cache of the 3scale batching policy'
)

local auth_cache_misses = prometheus(
  'counter',
  'batching_policy_auths_cache_misses',
  "Misses in the auths cache of the 3scale batching policy"
)

local function inc_auth_cache_hits()
  return auth_cache_hits and auth_cache_hits:inc()
end

local function inc_auth_cache_misses()
  return auth_cache_misses and auth_cache_misses:inc()
end

local func_update_counters = {
  [true] = inc_auth_cache_hits,
  [false] = inc_auth_cache_misses
}

function _M.update_cache_counters(cache_hit)
  func_update_counters[cache_hit]()
end

return _M
