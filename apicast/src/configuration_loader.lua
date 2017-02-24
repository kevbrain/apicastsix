local mock_loader = require 'configuration_loader.mock'
local file_loader = require 'configuration_loader.file'
local remote_loader_v1 = require 'configuration_loader.remote_v1'
local remote_loader_v2 = require 'configuration_loader.remote_v2'
local util = require 'util'
local env = require('resty.env')

local tostring = tostring
local error = error
local len = string.len
local assert = assert
local pcall = pcall
local tonumber = tonumber

local noop = function() end

local _M = {
  _VERSION = '0.1'
}

function _M.boot(host)
  return mock_loader.call() or file_loader.call() or remote_loader_v2.call() or remote_loader_v1.call(host) or error('missing configuration')
end

_M.mock = mock_loader.save

-- Cosocket API is not available in the init_by_lua* context (see more here: https://github.com/openresty/lua-nginx-module#cosockets-not-available-everywhere)
-- For this reason a new process needs to be started to download the configuration through 3scale API
function _M.init(cwd)
  cwd = cwd or env.get('TEST_NGINX_APICAST_PATH') or ngx.config.prefix()
  local config, err, code = util.system("cd '" .. cwd .."' && libexec/boot")

  -- Try to read the file in current working directory before changing to the prefix.
  if err then config = file_loader.call() end

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

local boot = {
  rewrite = noop,
  ttl = function() return tonumber(env.get('APICAST_CONFIGURATION_CACHE'), 10) end
}

function boot.init(proxy)
  local config, err = _M.init()
  local init, conferr = proxy:configure(config)

  if config and init then
    ngx.log(ngx.DEBUG, 'downloaded configuration: ', config)
  else
    ngx.log(ngx.EMERG, 'failed to load configuration, exiting: ', err or conferr)
    os.exit(1)
  end

  if boot.ttl() == 0 then
    ngx.log(ngx.EMERG, 'cache is off, cannot store configuration, exiting')
    os.exit(0)
  end
end

local function refresh_configuration(proxy)
  local config = _M.boot()
  local init, err = proxy:configure(config)

  if init then
    ngx.log(ngx.DEBUG, 'updated configuration via timer: ', config)
  else
    ngx.log(ngx.EMERG, 'failed to update configuration: ', err)
  end
end

function boot.init_worker(proxy)
  local interval = boot.ttl() or 0

  local function schedule(...)
    local ok, err = ngx.timer.at(...)

    if not ok then
      ngx.log(ngx.ERR, "failed to create the auto update timer: ", err)
      return
    end
  end

  local handler

  handler = function (premature, ...)
    if premature then return end

    ngx.log(ngx.INFO, 'auto updating configuration')

    local updated, err = pcall(refresh_configuration, ...)

    if updated then
      ngx.log(ngx.INFO, 'auto updating configuration finished successfuly')
    else
      ngx.log(ngx.ERR, 'auto updating configuration failed with: ', err)
    end

    schedule(interval, handler, ...)
  end

  if interval > 0 then
    schedule(interval, handler, proxy)
  end
end

local lazy = { init = noop, init_worker = noop }

function lazy.rewrite(proxy, host)
  if not proxy:configured(host) then
    local config = _M.boot(host)
    proxy:configure(config)
  end
end

local modes = {
  boot = boot, lazy = lazy, default = 'lazy'
}

function _M.new(mode)
  mode = mode or env.get('APICAST_CONFIGURATION_LOADER') or modes.default
  local loader = modes[mode]
  ngx.log(ngx.INFO, 'using ', mode, ' configuration loader')
  return assert(loader, 'invalid config loader mode')
end

return _M
