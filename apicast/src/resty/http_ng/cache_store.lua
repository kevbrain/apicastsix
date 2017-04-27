local lrucache = require 'resty.lrucache'
local ngx_re = require 'ngx.re'
local http_headers = require 'resty.http_ng.headers'

local setmetatable = setmetatable
local gsub = string.gsub
local lower = string.lower
local format = string.format

local _M = { default_size = 1000 }

local mt = { __index = _M }

function _M.new(size)
  return setmetatable({ cache = lrucache.new(size or _M.default_size) }, mt)
end

local function request_cache_key(request)
  -- TODO: verify if this is correct cache key and what are the implications
  -- FIXME: missing headers, ...
  return format('%s:%s', request.method, request.url)
end

function _M:get(request)
  local cache = self.cache
  if not cache then
    return nil, 'not initialized'
  end

  -- TODO: verify it is valid request per the RFC: https://tools.ietf.org/html/rfc7234#section-3

  local cache_key = request_cache_key(request)

  if not cache_key then return end

  local res, stale = cache:get(cache_key)

  -- TODO: handle stale responses per the RFC: https://tools.ietf.org/html/rfc7234#section-4.2.4
  local serve_stale = false

  if res then
    return res
  elseif serve_stale then
    -- TODO: generate Warning header per the RFC: https://tools.ietf.org/html/rfc7234#section-4.2.4
    return stale
  end
end


local function parse_cache_control(value)
  if not value then return end

  local res, err = ngx_re.split(value, '\\s*,\\s*', 'oj')

  local cache_control = {}

  local t = {}

  for i=1, #res do
    local res, err = ngx_re.split(res[i], '=', 'oj', nil, 2, t)

    if err then
      ngx.log(ngx.WARN, err)
    else
      -- TODO: selectively handle quoted strings per the RFC: https://tools.ietf.org/html/rfc7234#section-5.2
      cache_control[gsub(lower(res[1]), '-', '_')] = tonumber(res[2]) or res[2] or true
    end
  end

  if err then
    ngx.log(ngx.WARN, err)
  end

  return cache_control
end

local function response_cache_key(response)
  return request_cache_key(response.request)
end

local function response_ttl(response)
  local cache_control = parse_cache_control(response.headers.cache_control)

  return cache_control.max_age
end


function _M:set(response)
  local cache = self.cache

  if not cache then
    return nil, 'not initialized'
  end

  -- TODO: verify it is valid response per the RFC: https://tools.ietf.org/html/rfc7234#section-3
  if not response then return end

  local cache_key = response_cache_key(response)

  if not cache_key then return end

  local ttl = response_ttl(response)

  if ttl then
    local res = {
      body = response.body,
      headers = http_headers.new(response.headers),
      status = response.status
    }

    cache:set(cache_key, res, ttl)
  end
end


return _M
