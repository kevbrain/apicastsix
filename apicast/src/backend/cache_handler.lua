local setmetatable = setmetatable

local _M = {
  handlers = { }
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
  return setmetatable({ handler = handler }, mt)
end


function _M.handlers.strict(cache, cached_key, response, ttl)
  if response.status == 200 then
    ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key, ', ttl: ', ttl )
    cache:set(cached_key, 200, ttl or 0)
    return true
  else
    ngx.log(ngx.NOTICE, 'apicast cache delete key: ', cached_key, ' cause status ', response.status)
    cache:delete(cached_key)
    return false, 'not authorized'
  end
end

return _M
