--- Caching policy
-- Configures a cache for the authentication calls against the 3scale backend.
-- The 3scale backend can authorize (status code = 200) and deny (status code =
-- 4xx) calls. When it fails, it returns a 5xx code.
-- This policy support three kinds of caching:
--   - Strict: it only caches authorized calls. Denied and failed calls
--     invalidate the cache entry.
--   - Resilient: caches authorized and denied calls. Failed calls do not
--     invalidate the cache. This allows us to authorize and deny calls
--     according to the result of the last request made even when backend is
--     down.
--   - None: disables caching.

local policy = require('apicast.policy')
local _M = policy.new('Caching policy')

local new = _M.new

local function strict_handler(cache, cached_key, response, ttl)
  if response.status == 200 then
    ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key, ', ttl: ', ttl)
    cache:set(cached_key, 200, ttl or 0)
  else
    ngx.log(ngx.NOTICE, 'apicast cache delete key: ', cached_key,
                        ' cause status ', response.status)
    cache:delete(cached_key)
  end
end

local function resilient_handler(cache, cached_key, response, ttl)
  local status = response.status

  if status and status < 500 then
    ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key,
                      ' status: ', status, ', ttl: ', ttl)

    cache:set(cached_key, status, ttl or 0)
  end
end

local function disabled_cache_handler()
  ngx.log(ngx.DEBUG, 'Caching is disabled. Skipping cache handler.')
end

local handlers = {
  resilient = resilient_handler,
  strict = strict_handler,
  none = disabled_cache_handler
}

local function handler(config)
  if not config.caching_type then
    ngx.log(ngx.ERR, 'Caching type not specified. Disabling cache.')
    return handlers.none
  end

  local res = handlers[config.caching_type]

  if not res then
    ngx.log(ngx.ERR, 'Invalid caching type. Disabling cache.')
    res = handlers.none
  end

  return res
end

--- Initialize a Caching policy.
-- @tparam[opt] table config
-- @field caching_type Caching type (strict, resilient)
function _M.new(config)
  local self = new()
  self.cache_handler = handler(config or {})
  return self
end

function _M:rewrite(context)
  context.cache_handler = self.cache_handler
end

return _M
