local setmetatable = setmetatable
local pcall = pcall

local _M = {
  handlers = setmetatable({}, { __index = { default = 'strict' } })
}

local mt = {
  __index = _M,
  __call = function(t, ...)
    local handler = t.handlers[t.handler]

    if handler then
      return handler(...)
    else
      return nil, 'missing handler'
    end
  end,
}

-- Returns the rejection reason from the headers of a 3scale backend response.
-- The header is set only when the authrep call to backend enables the option
-- to get the rejection reason. This is specified in the '3scale-options'
-- header of the request.
local function rejection_reason(response_headers)
  return response_headers and response_headers['3scale-rejection-reason']
end

function _M.new(handler)
  local name = handler or _M.handlers.default
  ngx.log(ngx.DEBUG, 'backend cache handler: ', name)
  return setmetatable({ handler = name }, mt)
end

local function cached_key_var()
  return ngx.var.cached_key
end

local function fetch_cached_key()
  local ok, stored = pcall(cached_key_var)

  return ok and stored
end

function _M.handlers.strict(cache, cached_key, response, ttl)
  if response.status == 200 then
    -- cached_key is set in post_action and it is in in authorize
    -- so to not write the cache twice lets write it just in authorize

    if fetch_cached_key(cached_key) ~= cached_key then
      ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key, ', ttl: ', ttl, ' sub: ')
      cache:set(cached_key, 200, ttl or 0)
    end

    return true
  else
    ngx.log(ngx.NOTICE, 'apicast cache delete key: ', cached_key, ' cause status ', response.status)
    cache:delete(cached_key)
    return false, rejection_reason(response.headers)
  end
end

function _M.handlers.resilient(cache, cached_key, response, ttl)
  local status = response.status

  if status and status < 500 then
    ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key, ' status: ', status, ', ttl: ', ttl )

    cache:set(cached_key, status, ttl or 0)

    local authorized = (status == 200)
    return authorized, (not authorized and rejection_reason(response.headers))
  end
end

return _M
