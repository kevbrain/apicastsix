local unpack = unpack
local concat = table.concat
local tostring = tostring
local tonumber = tonumber

local resty_url = require 'resty.url'
local http = require "resty.resolver.http"
local socket_resolver = require('resty.resolver.socket')
local configuration_parser = require 'configuration_parser'
local user_agent = require 'user_agent'
local env = require 'resty.env'

local _M = {
  version = '0.1'
}

function _M.call(host)
  local endpoint = env.get('THREESCALE_PORTAL_ENDPOINT')

  _M.wait(endpoint, tonumber(env.get("APICAST_CONFIGURATION_TIMEOUT") or 3))

  return _M.download(endpoint, host)
end

-- wait until a connection to a TCP socket can be established
function _M.wait(endpoint, timeout)
  local now = ngx.now()
  local fin = now + timeout
  local url, err = resty_url.split(endpoint)

  ngx.log(ngx.DEBUG, 'going to wait for ' .. tostring(timeout))

  if not url and err then
    return nil, err
  end

  local scheme, _, _, host, port, _ = unpack(url)

  if not port and scheme then
    if scheme == 'http' then
      port = 80
    elseif scheme == 'https' then
      port = 443
    else
      return nil, "unknown scheme " .. tostring(scheme) .. ' and port missing'
    end
  end

  while now < fin do
    local sock = socket_resolver.new(ngx.socket.tcp())
    local ok

    ok, err = sock:connect(host, port)

    if ok then
      ngx.log(ngx.DEBUG, 'connected to ' .. host .. ':' .. tostring(port))
      sock:close()
      break
    else
      ngx.log(ngx.DEBUG, 'failed to connect to ' .. host .. ':' .. tostring(port) .. ': ' .. err)
    end

    ngx.sleep(0.1)
    ngx.update_time()
    now = ngx.now()
  end

  return not err, err
end

function _M.download(endpoint, _)
  local url, err = resty_url.split(endpoint)

  if not url and err then
    return nil, err
  end

  local scheme, user, pass, host, port, path = unpack(url)
  if port then host = concat({host, port}, ':') end

  url = concat({ scheme, '://', host, path or '/admin/api/nginx/spec.json' }, '')


  local httpc = http.new()
  local headers = {}

  httpc:set_timeout(10000)

  if user or pass then
    headers['Authorization'] = "Basic " .. ngx.encode_base64(concat({ user or '', pass or '' }, ':'))
  end

  headers['User-Agent'] = user_agent()

  -- TODO: this does not fully implement HTTP spec, it first should send
  -- request without Authentication and then send it after gettting 401

  ngx.log(ngx.INFO, 'configuration request sent: ' .. url)

  local res
  res, err = httpc:request_uri(url, {
    method = "GET",
    headers = headers,
    ssl_verify = env.enabled('OPENSSL_VERIFY')
  })

  if err then
    ngx.log(ngx.WARN, 'configuration download error: ' .. err)
  end

  local body = res and res.body

  if body and res.status == 200 then
    ngx.log(ngx.DEBUG, 'configuration response received:' .. body)

    local ok
    ok, err = configuration_parser.decode(body)
    if ok then
      return body
    else
      ngx.log(ngx.WARN, 'configuration could not be decoded: ', body)
      return nil, err
    end
  else
    return nil, err or res.reason
  end
end

return _M
