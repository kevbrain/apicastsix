local setmetatable = setmetatable
local rawset = rawset
local pairs = pairs
local unpack = unpack
local assert = assert
local print = print
local type = type
local rawlen = rawlen
local next = next
local wait = ngx.thread.wait
local spawn = ngx.thread.spawn

local _M = {}

local response = require 'resty.http_ng.response'
local http = require 'resty.resolver.http'

_M.async = function(req)
  local httpc = http.new()

  local parsed_uri = assert(httpc:parse_uri(req.url))

  local scheme, host, port, path = unpack(parsed_uri)
  if not req.path then req.path = path end

  if #req.path == 0 then req.path = '/' end

  local ok, err = httpc:connect(host, port)

  if not ok then
    print('error connecting ', host, ':', port, ' : ', err)
    return response.error(err, req)
  end

  if scheme == 'https' then
    local verify = req.options and req.options.ssl and req.options.ssl.verify
    if type(verify) == 'nil' then verify = true end

    local session
    session, err = httpc:ssl_handshake(false, host, verify)

    if not session then
      return response.error(err, req)
    end
  end

  local res
  res, err = httpc:request(req)

  if res then
    return response.new(res.status, res.headers, function() return (res:read_body()) end)
  else
    return response.error(err, req)
  end
end

local function future(thread)
  local ok, res

  local function load(table)
    if not ok and not res then
      ok, res = wait(thread)

      rawset(table, 'ok', ok)

      if not ok then res = response.error(res) end

      for k,v in pairs(res) do
        if k == 'headers' then
          rawset(table, k, response.headers.new(v))
        else
          rawset(table, k, v)
        end
      end
    end
  end

  return setmetatable({}, {
    __len = function(table)
      load(table)
      return rawlen(table)
    end,
    __pairs = function(table)
      load(table)
      rawset(table, 'body', res.body)
      return next, table, nil
    end,
    __index = function (table, key)
      load(table)
      return res[key]
    end
  })
end

_M.send = function(request)
  local thread = spawn(_M.async, request)
  return future(thread)
end

return _M
