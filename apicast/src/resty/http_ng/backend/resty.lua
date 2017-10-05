------------
--- HTTP
-- HTTP client
-- @module http_ng.backend

local backend = {}
local response = require 'resty.http_ng.response'
local http = require 'resty.resolver.http'

--- Send request and return the response
-- @tparam http_ng.request request
-- @treturn http_ng.response
backend.send = function(_, request)
  local httpc = http.new()
  local ssl_verify = request.options and request.options.ssl and request.options.ssl.verify

  local res, err = httpc:request_uri(request.url, {
    method = request.method,
    body = request.body,
    headers = request.headers,
    ssl_verify = ssl_verify
  })

  if res then
    return response.new(request, res.status, res.headers, res.body)
  else
    return response.error(request, err)
  end
end


return backend
