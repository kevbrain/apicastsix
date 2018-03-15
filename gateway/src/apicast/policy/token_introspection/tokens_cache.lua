--- TokensCache
-- Tokens cache for the token introspection policy.

local setmetatable = setmetatable
local tonumber = tonumber

local lrucache = require('resty.lrucache')

local _M = { }

local mt = { __index = _M }

local function ttl_from_introspection(introspection_info)
  local token_exp = introspection_info.exp
  return token_exp and (tonumber(token_exp) - ngx.time())
end

function _M.new(max_ttl, max_cached_tokens)
  local self = setmetatable({}, mt)
  self.max_ttl = max_ttl
  self.storage = lrucache.new(max_cached_tokens or 10000)
  return self
end

function _M:get(token)
  return self.storage:get(token)
end

function _M:set(token, introspection_info)
  local ttl = ttl_from_introspection(introspection_info)

  if self.max_ttl and (not ttl or self.max_ttl < ttl) then
    ttl = self.max_ttl
  end

  -- If the config does not contain a max ttl and the token instrospection did
  -- not return one, we cannot cache the token.
  if ttl and ttl > 0 then
    self.storage:set(token, introspection_info, ttl)
  end
end

return _M
