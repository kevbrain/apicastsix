local backend = {}
local response = require 'resty.http_ng.response'
local http = require 'resty.http'

backend.send = function(request)
  local httpc = http.new()
  local ssl_verify = request.options and request.options.ssl and request.options.ssl.verify

  local res, err = httpc:request_uri(request.url, {
    method = request.method,
    body = request.body,
    headers = request.headers,
    ssl_verify = ssl_verify
  })

  if res then
    return response.new(res.status, res.headers, res.body)
  else
    return response.error(err)
  end
end


return backend
