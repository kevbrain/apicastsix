local setmetatable = setmetatable

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

function _M.new(handler)
  local name = handler or _M.handlers.default
  ngx.log(ngx.DEBUG, 'backend cache handler: ', name)
  return setmetatable({ handler = name }, mt)
end

function _M.handlers.strict(cache, cached_key, response, ttl)
  if response.status == 200 then
    -- cached_key is set in post_action and it is in in authorize
    -- so to not write the cache twice lets write it just in authorize
    if ngx.var.cached_key ~= cached_key then
      ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key, ', ttl: ', ttl )
      cache:set(cached_key, 200, ttl or 0)
    end

    return true
  else
    ngx.log(ngx.NOTICE, 'apicast cache delete key: ', cached_key, ' cause status ', response.status)
    cache:delete(cached_key)
    return false, 'not authorized'
  end
end

function _M.handlers.resilient(cache, cached_key, response, ttl)
  local status = response.status

  if status and status < 500 then
    ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key, ' status: ', status, ', ttl: ', ttl )

    cache:set(cached_key, status, ttl or 0)

    return status == 200
  end
end

return _M
