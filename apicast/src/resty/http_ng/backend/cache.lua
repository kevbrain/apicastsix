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

  local response, err

  if cache_store then
    response, err = cache_store:send(backend, request)
  else
    response, err = backend:send(request)
  end

  return response, err
end

return _M
