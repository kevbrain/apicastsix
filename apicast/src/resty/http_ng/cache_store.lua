local lrucache = require 'resty.lrucache'
local ngx_re = require 'ngx.re'
local http_headers = require 'resty.http_ng.headers'

local setmetatable = setmetatable
local gsub = string.gsub
local lower = string.lower
local format = string.format
local tonumber = tonumber
local max = math.max
local pairs = pairs
local floor = math.floor

local _M = { default_size = 100 }

local mt = { __index = _M }

function _M.new(store)
  return setmetatable({ cache = store or lrucache.new(_M.default_size) }, mt)
end

local function TODO(ret)
  return ret
end

local function request_cache_key(request)
  -- TODO: verify if this is correct cache key and what are the implications
  -- FIXME: missing headers, ...
  -- Match Effective Request URI: https://tools.ietf.org/html/rfc7230#section-5.5
  -- Calculate Secondary Key wtih Vary: https://tools.ietf.org/html/rfc7234#section-4.1
  return format('%s:%s', request.method, request.url)
end

local function parse_cache_control(value)
  if not value then return end

  local res, err = ngx_re.split(value, '\\s*,\\s*', 'oj')

  local cache_control = {}

  local t = {}

  for i=1, #res do
    local r, e = ngx_re.split(res[i], '=', 'oj', nil, 2, t)

    if e then
      ngx.log(ngx.WARN, e)
    else
      -- TODO: selectively handle quoted strings per the RFC: https://tools.ietf.org/html/rfc7234#section-5.2
      cache_control[gsub(lower(r[1]), '-', '_')] = tonumber(r[2]) or r[2] or true
    end
  end

  if err then
    ngx.log(ngx.WARN, err)
  end

  return cache_control
end

local empty_t = {}

local function no_cache(http)
  -- the presented request does not contain the no-cache pragma
  -- (Section 5.4), nor the no-cache cache directive (Section 5.2.1),
  -- unless the stored response is successfully validated (Section 4.3)
  -- TODO: implement the "unless the stored response is successfuly validated"

  local pragma = parse_cache_control(http.headers.pragma) or empty_t
  local cache_control = parse_cache_control(http.headers.cache_control) or empty_t

  return pragma.no_cache or cache_control.no_cache
end

local function reuse_stored_response(request)
  -- https://tools.ietf.org/html/rfc7234#section-4
  return request.version > 1.0 and not no_cache(request)
end

-- Invalidation https://tools.ietf.org/html/rfc7234#section-4.4
--function _M:delete(response)
--  -- TODO: implement invalidation (Section 4.4)
--end

--- Section 4.2.1. Calculating Freshness Lifetime
-- https://tools.ietf.org/html/rfc7234#section-4.2.1
local function freshness_lifetime(response)
  local cache_control = parse_cache_control(response.headers.cache_control) or empty_t
  local expires = ngx.parse_http_time(response.headers.expires or '')
  local date = ngx.parse_http_time(response.headers.date)

  --  A cache can calculate the freshness lifetime (denoted as freshness_lifetime)
  --  of a response by using the first match of the following:
  return tonumber(
    --  If the cache is shared and the s-maxage response directive
    -- (Section 5.2.2.9) is present, use its value,
    (_M.shared and cache_control.s_maxage)
        or
    --  If the max-age response directive (Section 5.2.2.8) is present, use its value,
    cache_control.max_age
      or
    --  If the Expires response header field (Section 5.3) is present, use
    --  its value minus the value of the Date response header field,
    (expires and expires - date)
      or
    --  Otherwise, no explicit expiration time is present in the response.
    --  A heuristic freshness lifetime might be applicable; see Section 4.2.2.
    0 -- TODO: implement Heuristic Freshness https://tools.ietf.org/html/rfc7234#section-4.2.2
  )
end

--- Section 4.2.3. Calculating Age
-- https://tools.ietf.org/html/rfc7234#section-4.2.3
local function current_age(response)
  --  The term "age_value" denotes the value of the Age header field
  --  (Section 5.1), in a form appropriate for arithmetic operation; or
  --  0, if not available.
  local age_value = 0

  --  The term "date_value" denotes the value of the Date header field,
  --  in a form appropriate for arithmetic operations.  See Section
  --  7.1.1.2 of [RFC7231](https://tools.ietf.org/html/rfc7231#section-7.1.1.2)
  --  for the definition of the Date header field,
  --  and for requirements regarding responses without it.
  local date_value = ngx.parse_http_time(response.headers.date)

  --  The term "now" means "the current value of the clock at the host
  --  performing the calculation".  A host ought to use NTP ([RFC5905])
  --  or some similar protocol to synchronize its clocks to Coordinated
  --  Universal Time.
  local now = ngx.now()

  --  The current value of the clock at the host at the time the request
  --  resulting in the stored response was made.
  local request_time = response.request_time

  -- The current value of the clock at the host at the time the
  -- response was received.
  local response_time = response.response_time

  -- A response's age can be calculated in two entirely independent ways:

  -- 1. the "apparent_age": response_time minus date_value, if the local
  -- clock is reasonably well synchronized to the origin server's
  -- clock. If the result is negative, the result is replaced by zero.

  local apparent_age = max(0, response_time - date_value)

  -- 2. the "corrected_age_value", if all of the caches along the
  -- response path implement HTTP/1.1.  A cache MUST interpret this
  -- value relative to the time the request was initiated, not the
  -- time that the response was received.
  local response_delay = response_time - request_time
  local corrected_age_value = age_value + response_delay

  local corrected_initial_age = max(apparent_age, corrected_age_value)

  -- The current_age of a stored response can then be calculated by adding
  -- the amount of time (in seconds) since the stored response was last
  -- validated by the origin server to the corrected_initial_age.

  local resident_time = now - response_time

  return corrected_initial_age + resident_time
end

local function fresh_response(response)
  if not response then return nil, 'no response' end

  local age = current_age(response)
  local response_is_fresh = (freshness_lifetime(response) > age)

  if response_is_fresh then
    response.headers.age = floor(age)
  end

  return response_is_fresh-- TODO: implement freshness https://tools.ietf.org/html/rfc7234#section-4.2
end

local function stale_response(response)
  if not response then return nil, 'no response' end

  -- TODO: implement https://tools.ietf.org/html/rfc7234#section-4.2.4
  local cache_control = parse_cache_control(response.headers.cache_control) or empty_t

  return cache_control.must_revalidate
end

local function serve_stale_response(response)
  -- TODO: handle stale responses per the RFC: https://tools.ietf.org/html/rfc7234#section-4.2.4

  --  A cache MUST NOT generate a stale response if it is prohibited by an
  --  explicit in-protocol directive (e.g., by a "no-store" or "no-cache"
  --  cache directive, a "must-revalidate" cache-response-directive, or an
  --  applicable "s-maxage" or "proxy-revalidate" cache-response-directive; see Section 5.2.2).

  return TODO(not response)
end

function _M:get(request)
  local cache = self.cache
  if not cache then
    return nil, 'not initialized'
  end

  -- TODO: verify it is valid request per the RFC: https://tools.ietf.org/html/rfc7234#section-3

  request.headers = request.headers or http_headers.new()
  request.headers.via = (request.headers.via or {})
  request.headers.via['1.1 APIcast'] = true

  if not reuse_stored_response(request) then
    return nil, 'not reusing stored response'
  end

  local cache_key = request_cache_key(request)

  if not cache_key then return nil, 'missing cache key' end

  local res = cache:get(cache_key)

  if fresh_response(res) then
    res.headers.x_cache_status = 'HIT'
    return res
  elseif res then
    res.headers.x_cache_status = 'EXPIRED'
  end

  if stale_response(res) then
    res.headers.x_cache_status = 'STALE'

    if serve_stale_response(res) then
      -- TODO: generate Warning header per the RFC: https://tools.ietf.org/html/rfc7234#section-4.2.4
      return res
    end
  end

  if res then
    return res, 'must-revalidate'
  end

  return res
end

local function response_cache_key(response)
  return request_cache_key(response.request)
end

local function response_ttl(response)
  local cache_control = parse_cache_control(response.headers.cache_control) or empty_t

  return cache_control.max_age
end

local allowed_status_codes = {
  [200] = true
}

local allowed_methods = {
  GET = true,
  HEAD = true
}

local function cacheable_response(response)
  -- TODO: verify it is valid response per the RFC: https://tools.ietf.org/html/rfc7234#section-3

  local request = response.request

  local request_cache_control = parse_cache_control(request.headers.cache_control) or empty_t
  local response_cache_control = parse_cache_control(response.headers.cache_control) or empty_t

  --  A cache MUST NOT store a response to any request, unless:
  return (
    --  The request method is understood by the cache and defined as being cacheable
    allowed_methods[request.method]
      and
    --  the response status code is understood by the cache
    allowed_status_codes[response.status]
      and
    --  the "no-store" cache directive (see Section 5.2) does not appear in request or response header fields
    not (request_cache_control.no_store or response_cache_control.no_store)
      and
    --  the "private" response directive (see Section 5.2.2.6) does not appear in the response, if the cache is shared
    not (_M.shared and response_cache_control.private)
      and
    --  the Authorization header field (see Section 4.2 of [RFC7235]) does
    --  not appear in the request, if the cache is shared, unless the
    --  response explicitly allows it (see Section 3.2)
    not (_M.shared and request.headers.authorization)
      and ( -- the response either:
      --  contains an Expires header field (see Section 5.3)
      response.headers.expires
        or
      -- contains a max-age response directive (see Section 5.2.2.8)
      response_cache_control.max_age
        or
      -- contains a s-maxage response directive (see Section 5.2.2.9) and the cache is shared
      (response_cache_control.s_maxage and _M.shared)
        or
      --  contains a Cache Control Extension (see Section 5.2.3) allows it to be cached
      TODO(false) -- TODO: https://tools.ietf.org/html/rfc7234#section-5.2.3
        or
      --  has a status code that is defined as cacheable by default (see Section 4.2.2)
      TODO(false) -- TODO: https://tools.ietf.org/html/rfc7234#section-4.2.2
        or
      --  contains a public response directive (see Section 5.2.2.5).
      TODO(false) -- TODO: https://tools.ietf.org/html/rfc7234#section-5.2.2.5
    )
  )
end

function _M.entry(response)
  return {
    body = response.body,
    headers = http_headers.new(response.headers),
    status = response.status,
    response_time = response.time,
    request_time = response.request.time
  }
end

local function send(backend, request)
  request.time = ngx.now()
  local res, err = backend:send(request)

  if res then
    res.time = ngx.now()
  end

  return res, err
end


function _M:send(backend, request)
  local response, error = self:get(request)

  if response and error then
    response, error = self:revalidate(response, backend, request)
  elseif error then
    ngx.log(ngx.WARN, 'http cache store: ', error) -- FIXME: for debuging
  end

  if not response then
    response, error = send(backend, request)

    if response and not error then
      local ok, err = self:set(response)

      if not ok and err then
        ngx.log(ngx.WARN, 'http cache store: ', err) -- FIXME: for debugging we need more info
      end
    end
  end

  return response, error
end

local function freshen_stored_response(stored, response)
  local response_etag = response.headers.etag
  local stored_etag = stored.headers.etag

  local update

  --  If the new response contains a strong validator (see Section 2.1
  --  of [RFC7232]), then that strong validator identifies the selected
  --  representation for update.  All of the stored responses with the
  --  same strong validator are selected.  If none of the stored
  --  responses contain the same strong validator, then the cache MUST
  --  NOT use the new response to update any stored responses.
  if response_etag then
    -- FIXME: yeah, we should first check if the ETag is strong or weak, but
    -- we don't support weak ETags yet and treat them as strong.

    --  If the new response contains a weak validator and that validator
    --  corresponds to one of the cache's stored responses, then the most
    --  recent of those matching stored responses is selected for update.
    if stored_etag == response_etag then
      update = stored
    else
      return stored
    end
  end

  --  If the new response does not include any form of validator (such
  --  as in the case where a client generates an If-Modified-Since
  --  request from a source other than the Last-Modified response header
  --  field), and there is only one stored response, and that stored
  --  response also lacks a validator, then that stored response is
  --  selected for update.

  if (not response_etag and not response.headers.last_modified) and
     (not stored_etag and not stored.headers.last_modified) then
    update = stored
  end

  -- If a stored response is selected for update, the cache MUST:
  if update then
    --  delete any Warning header fields in the stored response with
    --  warn-code 1xx (see Section 5.5);
    -- TODO: implement Warning header

    --  retain any Warning header fields in the stored response with
    --  warn-code 2xx; and,
    -- TODO: implement Warning header

    --  use other header fields provided in the 304 (Not Modified)
    --  response to replace all instances of the corresponding header
    --  fields in the stored response.

    for name, value in pairs(response.headers) do
      if update.headers[name] then
        update.headers[name] = value
      end
    end
    update.headers.x_cache_status = 'REVALIDATED'
  end

  -- FIXME: set the X-Cache-Status to something other than UPDATING (from the revalidate

  return stored
end

function _M:revalidate(response, backend, request)
  local etag = response.headers.etag
  local last_modified = response.headers.last_modified

  response.headers.x_cache_status = 'UPDATING'

  -- One such validator is the timestamp given in a Last-Modified header
  -- field (Section 2.2 of [RFC7232]), which can be used in an
  -- If-Modified-Since header field for response validation, or in an
  -- If-Unmodified-Since or If-Range header field for representation
  -- selection (i.e., the client is referring specifically to a previously
  -- obtained representation with that timestamp).
  request.headers.if_modified_since = last_modified

  --  Another validator is the entity-tag given in an ETag header field
  --  (Section 2.3 of [RFC7232]).  One or more entity-tags, indicating one
  --  or more stored responses, can be used in an If-None-Match header
  --  field for response validation, or in an If-Match or If-Range header
  --  field for representation selection (i.e., the client is referring
  --  specifically to one or more previously obtained representations with
  --  the listed entity-tags).
  request.headers.if_none_match = etag

  -- TODO: implement representation selection validation

  local res, err = send(backend, request)

  --  A 304 (Not Modified) response status code indicates that the
  --  stored response can be updated and reused; see Section 4.3.4.
  if res and res.status == 304 then
    return freshen_stored_response(response, res)

  --  However, if a cache receives a 5xx (Server Error) response while
  --  attempting to validate a response, it can either forward this
  --  response to the requesting client, or act as if the server failed
  --  to respond.  In the latter case, the cache MAY send a previously
  --  stored response (see Section 4.2.4).
  elseif res.status >= 500 and res.status < 600 then
    return response -- returns cached response

  --  A full response (i.e., one with a payload body) indicates that
  --  none of the stored responses nominated in the conditional request
  --  is suitable.  Instead, the cache MUST use the full response to
  --  satisfy the request and MAY replace the stored response(s).
  elseif res then
    self:set(res)
    return res
  end

  return res, err
end

function _M:set(response)
  local cache = self.cache

  if not cache then
    return nil, 'not initialized'
  end

  response.headers.x_cache_status = 'MISS'

  if not cacheable_response(response) then
    return nil, 'not cacheable response'
  end

  local cache_key = response_cache_key(response)

  if not cache_key then return nil, 'invalid cache key' end

  local ttl = response_ttl(response)

  if ttl then
    local res = _M.entry(response)

    cache:set(cache_key, res)

    return res
  end
end


return _M
