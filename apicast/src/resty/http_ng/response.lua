local assert = assert
local rawget = rawget
local rawset = rawset
local type = type
local setmetatable = setmetatable
------------
-- @module middleware

--- response
-- @type HTTP

--- Response returned by http.get and similar calls
-- @table response
-- @field[type=int] status HTTP Status Code
-- @field[type=table] headers HTTP Headers
-- @field[type=string] body response body
-- @field[type=bool] ok


local response = {}
response.headers = require 'resty.http_ng.headers'


function response.new(request, status, headers, body)
  assert(status, 'missing request status')
  assert(body, 'missing request body')

  local mt = {}
  mt['__index'] = function(table, key)
    local generator = rawget(mt, key)
    if generator then
      rawset(table, key, generator(table))
    end
    return rawget(table, key)
  end

  local res = {
    status = status,
    headers = response.headers.new(headers),
    ok = true,
    request = request
  }

  if type(body) == 'string' then
    res.body = body
  elseif type(body) == 'function' then
    mt.body = body
  end

  -- https://tools.ietf.org/html/rfc7231#section-7.1.1.2
  -- > A recipient with a clock that receives a response message without a
  --   Date header field MUST record the time it was received and append a
  --   corresponding Date header field to the message's header section if it
  --   is cached or forwarded downstream.
  res.headers.date = res.headers.date or ngx.http_time(ngx.time())

  return setmetatable(res, mt)
end

function response.error(request, message)
  assert(request, 'missing request')
  assert(message, 'missing message')
  return { ok = false, error = message, request = request, status = 0, headers = {} }
end

return response
