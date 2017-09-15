local setmetatable = setmetatable
local rawset = rawset
local pairs = pairs
local unpack = unpack
local assert = assert
local type = type
local rawlen = rawlen
local next = next
local wait = ngx.thread.wait
local spawn = ngx.thread.spawn

local _M = {}

local response = require 'resty.http_ng.response'
local http = require 'resty.resolver.http'

_M.async = function(request)
  local httpc = http.new()

  local parsed_uri = assert(httpc:parse_uri(assert(request.url, 'missing url')))

  local scheme, host, port, path = unpack(parsed_uri)
  if not request.path then request.path = path end

  if #request.path == 0 then request.path = '/' end

  local timeout = request.timeout or (request.options and request.options.timeout)

  if type(timeout) == 'number' then
    httpc:set_timeout(timeout)
  elseif type(timeout) == 'table' then
    local connect_timeout = timeout.connect
    local send_timeout = timeout.send
    local read_timeout = timeout.read

    if httpc.set_timeouts then -- lua-resty-http >= 0.10
      httpc:set_timeouts(connect_timeout, send_timeout, read_timeout)
    else
      httpc.sock:settimeouts(connect_timeout, send_timeout, read_timeout)
    end
  end

  local ok, err = httpc:connect(host, port)

  if not ok then
    return response.error(request, err)
  end

  if scheme == 'https' then
    local verify = request.options and request.options.ssl and request.options.ssl.verify
    if type(verify) == 'nil' then verify = true end

    local session
    session, err = httpc:ssl_handshake(false, host, verify)

    if not session then
      return response.error(request, err)
    end
  end

  local res
  res, err = httpc:request(request)

  if res then
    return response.new(request, res.status, res.headers, function() return (res:read_body()) end)
  else
    return response.error(request, err)
  end
end

local function future(thread, request)
  local ok, res

  local function load(table)
    if not ok and not res then
      ok, res = wait(thread)

      rawset(table, 'ok', ok)

      if not ok then res = response.error(request, res or 'failed to create async request') end

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

_M.send = function(_, request)
  local thread = spawn(_M.async, request)
  return future(thread, request)
end

return _M
