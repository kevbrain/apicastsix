local find = string.find
local sub = string.sub
local assert = assert
local setmetatable = setmetatable

------------
-- @module middleware

--- options
-- @type HTTP

--- Options that can be passed to @{http} calls.
-- @table options
-- @field[type=table] headers table of HTTP headers
-- @field[type=table] ssl table with ssl options
-- @usage http.get(uri, { ssl = { verify = false }})
-- @usage http.get(uri, { headers = { my_header = 'value' }})

local request = { }

request.headers = require 'resty.http_ng.headers'

local function extract_host(url)
  local _, last = find(url, '://', 0, true)
  local len = find(url, '/', last + 1, true)

  if len then len = len - 1 end

  return sub(url, last + 1, len)
end

function request.extract_headers(req)
  local options = req.options or {}
  local headers = request.headers.new(options.headers)

  headers.user_agent = headers.user_agent or 'APIcast (+https://www.apicast.io)'
  headers.host = headers.host or extract_host(req.url)
  headers.connection = headers.connection or 'Keep-Alive'

  options.headers = nil

  return headers
end

function request.new(req)
  assert(req)
  assert(req.url)
  assert(req.method)

  req.version = req.version or 1.1
  req.options = req.options or {}
  req.client = req.client or {}

  req.headers = request.extract_headers(req)
  req.options.ssl = req.options.ssl or { verify = true }

  setmetatable(req, {
    __index =  {
      serialize = req.serializer or function() end
    }
  })

  req.serialize(req)

  return req
end

return request
