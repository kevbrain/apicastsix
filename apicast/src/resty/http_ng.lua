------------
--- HTTP NG module
-- Implements HTTP client.
-- @module http_ng

--- HTTP Client
-- @type HTTP

local type = type
local unpack = unpack
local assert = assert
local tostring = tostring
local setmetatable = setmetatable
local getmetatable = getmetatable
local rawset = rawset
local upper = string.upper
local rawget = rawget
local pack = table.pack
local next = next
local pairs = pairs
local concat = table.concat


local resty_backend = require 'resty.http_ng.backend.resty'
local json = require 'cjson'
local request = require 'resty.http_ng.request'
local resty_url = require 'resty.url'
local http_headers = require 'resty.http_ng.headers'

local DEFAULT_PATH = ''

local http = { request = request }

local function merge(...)
  local all = pack(...)

  if #all == 1 then return all[next(all)] end

  local res

  for i = 1, all.n do
    local t = all[i]

    if type(t) == 'table' then
      res = res or setmetatable({}, getmetatable(t))
      for k,v in pairs(t) do
        res[k] = merge(res[k], v)
      end
    elseif type(t) ~= 'nil' then
      res = t
    end
  end

  return res
end

local function get_request_params(method, client, url, options)
  local opts = {}
  local scheme, user, pass, host, port, path = unpack(assert(resty_url.split(url)))
  if port then host = concat({host, port}, ':') end

  opts.headers = http_headers.new()
  opts.headers.host = host

  if user or pass then
    opts.headers.authorization = "Basic " .. ngx.encode_base64(concat({ user or '', pass or '' }, ':'))
  end

  return {
    url         = concat({ scheme, '://', host, path or DEFAULT_PATH }, ''),
    method      = method,
    options     = merge(opts, rawget(client, 'options'), options),
    client      = client,
    serializer  = client.serializer or http.serializers.default
  }
end

http.method = function(method, client)
  assert(method)
  assert(client)

  return function(url, options)
    if type(url) == 'table' and not options then
      options = url
      url = unpack(url)
    end

    assert(url, 'url as first parameter is required')

    local req_params = get_request_params(method, client, url, options)
    local req = http.request.new(req_params)

    return client.backend:send(req)
  end
end

http.method_with_body = function(method, client)
  assert(method)
  assert(client)

  return function(url, body, options)
    if type(url) == 'table' and not body and not options then
      options = url
      url, body = unpack(url)
    end

    assert(url, 'url as first parameter is required')
    assert(body, 'body as second parameter is required')

    local req_params = get_request_params(method, client, url, options)
    req_params.body = body
    local req = http.request.new(req_params)

    return client.backend:send(req)
  end
end

--- Make GET request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.get
http.GET = http.method

--- Make HEAD request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.head
http.HEAD = http.method

--- Make DELETE request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.delete
http.DELETE = http.method

--- Make OPTIONS request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.options
http.OPTIONS = http.method

--- Make PUT request.
-- The **body** is serialized by @{HTTP.urlencoded} unless you used different serializer.
-- @param[type=string] url
-- @param[type=string|table] body
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.put
http.PUT = http.method_with_body

--- Make POST request.
-- The **body** is serialized by @{HTTP.urlencoded} unless you used different serializer.
-- @param[type=string] url
-- @param[type=string|table] body
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.post
http.POST = http.method_with_body

--- Make PATCH request.
-- The **body** is serialized by @{HTTP.urlencoded} unless you used different serializer.
-- @param[type=string] url
-- @param[type=string|table] body
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.patch
http.PATCH = http.method_with_body

http.TRACE = http.method_with_body

http.serializers = {}

--- Urlencoded serializer
-- Serializes your data to `application/x-www-form-urlencoded` format
-- and sets correct Content-Type header.
-- @http HTTP.urlencoded
-- @usage http.urlencoded.post(url, { example = 'table' })
http.serializers.urlencoded = function(req)
  req.body = ngx.encode_args(req.body)
  req.headers.content_type = req.headers.content_type or 'application/x-www-form-urlencoded'
  http.serializers.string(req)
end

http.serializers.string = function(req)
  req.body = tostring(req.body)
  req.headers['Content-Length'] = #req.body
end

--- JSON serializer
-- Converts the body to JSON unless it is already a string
-- and sets correct Content-Type `application/json`.
-- @http HTTP.json
-- @usage http.json.post(url, { example = 'table' })
-- @see http.post
http.serializers.json = function(req)
  if type(req.body) ~= 'string' then
    req.body = json.encode(req.body)
  end
  req.headers.content_type = req.headers.content_type or 'application/json'
  http.serializers.string(req)
end

http.serializers.default = function(req)
  if req.body then
    if type(req.body) ~= 'string' then
      http.serializers.urlencoded(req)
    else
      http.serializers.string(req)
    end
  end
end

local function add_http_method(client, method)
  local m = upper(method)

  local cached = rawget(client, m)

  if cached then
    return cached
  end

  local generator = http[m]

  if generator then
    local func = generator(m, client)
    rawset(client, m, func)
    return func
  end
end

local function chain_serializer(client, format)
  local serializer = http.serializers[format]

  if serializer then
    return http.new{ backend = client.backend, serializer = serializer }
  end
end

local function generate_client_method(client, method_or_format)
  return add_http_method(client, method_or_format) or chain_serializer(client, method_or_format)
end

function http.new(client)
  client = client or { }
  client.backend = client.backend or resty_backend

  return setmetatable(client, { __index  = generate_client_method  })
end

return http
