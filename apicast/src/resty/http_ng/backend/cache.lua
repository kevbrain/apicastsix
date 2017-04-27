local setmetatable = setmetatable

------------
--- HTTP
-- HTTP client
-- @module http_ng.backend

local _M = {}

local mt = { __index = _M }

function _M.new(backend, options)
  local opts = options or {}
  return setmetatable({
    backend = backend, cache_store = opts.cache_store
  }, mt)
end

--- Send request and return the response
-- @tparam http_ng.request request
-- @treturn http_ng.response
function _M:send(request)
  local cache_store = self.cache_store
  local backend = self.backend

  if cache_store then
     local res, err = cache_store:get(request)

     if not res then

       res, err = backend:send(request)
       if res and not err then
         cache_store:set(res)
       end
     end

     return res, err
  else
    return backend:send(request)
  end
end

return _M
