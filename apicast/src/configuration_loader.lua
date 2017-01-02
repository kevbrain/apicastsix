local resty_url = require 'resty.url'
local http = require "resty.http"
local configuration = require 'configuration'
local util = require 'util'

local getenv = os.getenv
local tostring = tostring
local unpack = unpack
local concat = table.concat
local error = error
local open = io.open
local assert = assert
local len = string.len

local _M = {
  _VERSION = '0.1'
}

function _M.read(path)
  if not path or len(tostring(path)) == 0 then
    return nil, 'missing path'
  end
  ngx.log(ngx.INFO, 'configuration loading file ' .. path)
  return assert(open(path)):read('*a')
end

function _M.file(path)
  local file = path or getenv('THREESCALE_CONFIG_FILE')

  return _M.read(file)
end

function _M.boot()
  local endpoint = getenv('THREESCALE_PORTAL_ENDPOINT')

  return _M.load() or _M.file() or _M.wait(endpoint, 3) or _M.download(endpoint) or _M.curl(endpoint) or error('missing configuration')
end

function _M.save(config)
  _M.config = config -- TODO: use shmem
end

function _M.load()
  return _M.config
end


-- Cosocket API is not available in the init_by_lua* context (see more here: https://github.com/openresty/lua-nginx-module#cosockets-not-available-everywhere)
-- For this reason a new process needs to be started to download the configuration through 3scale API
function _M.init()
  local config, err, code = util.system("cd '" .. ngx.config.prefix() .."' && libexec/boot")

  -- Try to read the file in current working directory before changing to the prefix.
  if err then config = _M.file() end

  if config and len(config) > 0 then
    return config
  elseif err then
    if code then
      ngx.log(ngx.ERR, 'boot could not get configuration, ' .. tostring(err) .. ': '.. tostring(code))
      return nil, err
    else
      ngx.log(ngx.ERR, 'boot failed read: '.. tostring(err))
      return nil, err
    end
  end
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
    local sock = ngx.socket.tcp()
    local ok

    ok, err = sock:connect(host, port)

    if ok then
      ngx.log(ngx.DEBUG, 'connected to ' .. host .. ':' .. tostring(port))
      sock:close()
      return
    else
      ngx.log(ngx.DEBUG, 'failed to connect to ' .. host .. ':' .. tostring(port) .. ': ' .. err)
    end

    ngx.sleep(0.1)
    ngx.update_time()
    now = ngx.now()
  end

  return nil, err
end

function _M.download(endpoint)
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

  -- TODO: this does not fully implement HTTP spec, it first should send
  -- request without Authentication and then send it after gettting 401

  ngx.log(ngx.INFO, 'configuration request sent: ' .. url)

  local res
  res, err = httpc:request_uri(url, {
    method = "GET",
    headers = headers,
    ssl_verify = false
  })

  if err then
    ngx.log(ngx.WARN, 'configuration download error: ' .. err)
  end

  local body = res and (res.body or res:read_body())

  if body and res.status == 200 then
    ngx.log(ngx.DEBUG, 'configuration response received:' .. body)

    local ok
    ok, err = configuration.decode(body)
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

-- curl is used because resty command that runs libexec/boot does not have correct DNS resolvers set up
-- resty is using google's public DNS servers and there is no way to change that
function _M.curl(endpoint)
  local url, err = resty_url.split(endpoint)

  if not url and err then
    return nil, err
  end

  local timeout = getenv('CURL_TIMEOUT') or 3
  local scheme, user, pass, host, port, path = unpack(url)

  if port then host = concat({host, port}, ':') end

  url = concat({ scheme, '://', concat({user or '', pass or ''}, ':'), '@', host, path or '/admin/api/nginx/spec.json' }, '')

  local config, stderr, code = util.system('curl --silent --show-error --fail --max-time ' .. timeout .. ' --location ' .. url)

  ngx.log(ngx.INFO, 'configuration request sent: ', url)

  if config and len(config) > 0 then
    ngx.log(ngx.DEBUG, 'configuration response received:', config)
    return config
  else
    if code then
      ngx.log(ngx.ERR, 'configuration download error ', stderr, ' ', code)
      return nil, 'curl fished with ' .. stderr .. ' ' .. code
    else
      ngx.log(ngx.WARN, 'configuration download error: ',  stderr)
      return nil, stderr
    end
  end
end

return _M
