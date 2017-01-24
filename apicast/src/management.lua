local _M = {}

local cjson = require('cjson')
local provider = require('proxy')
local router = require('router')
local configuration_parser = require('configuration_parser')
local configuration_loader = require('configuration_loader')
local inspect = require('inspect')

local live = cjson.encode({status = 'live', success = true})

function _M.ready()
  local status = _M.status()
  local code = status.success and 200 or 412

  ngx.status = code
  ngx.say(cjson.encode(status))
end

function _M.live()
  ngx.status = 200
  ngx.say(live)
end

function _M.status()
  -- TODO: this should be fixed for multi-tenant deployment
  local has_configuration = provider.configuration.configured
  local has_services = #(provider.configuration:all()) > 0

  if not has_configuration then
    return { status = 'error', error = 'not configured',  success = false }
  elseif not has_services then
    return { status = 'warning', warning = 'no services', success = false }
  else
    return { status = 'ready', success = true }
  end
end

function _M.config()
  local config = provider.configuration
  local contents = cjson.encode(config.configured and { services = config:all() } or nil)

  ngx.header.content_type = 'application/json; charset=utf-8'
  ngx.status = 200
  ngx.say(contents)
end

function _M.update_config()
  ngx.req.read_body()

  ngx.log(ngx.DEBUG, 'management config update')
  local data = ngx.req.get_body_data()
  local file = ngx.req.get_body_file()

  if not data then
    data = assert(io.open(file)):read('*a')
  end

  local config = configuration_parser.decode(data)
  provider.configure(config)
  -- TODO: respond with proper 304 Not Modified when config is the same
  local response = cjson.encode({ status = 'ok', config = config or cjson.null })
  ngx.header.content_type = 'application/json; charset=utf-8'
  ngx.say(response)
end

function _M.delete_config()
  ngx.log(ngx.DEBUG, 'management config delete')

  provider.configuration:reset()
  -- TODO: respond with proper 304 Not Modified when config is the same
  local response = cjson.encode({ status = 'ok', config = cjson.null })
  ngx.header.content_type = 'application/json; charset=utf-8'
  ngx.say(response)
end

local util = require 'util'

function _M.boot()
  local data = util.timer('configuration.boot', configuration_loader.boot)
  local config = configuration_parser.decode(data)
  local response = cjson.encode({ status = 'ok', config = config or cjson.null })

  ngx.log(ngx.DEBUG, 'management boot config:' .. inspect(data))

  provider.init(config)

  ngx.say(response)
end

function _M.router()
  local r = router.new()

  r:get('/config', _M.config)
  r:put('/config', _M.update_config)
  r:post('/config', _M.update_config)
  r:delete('/config', _M.delete_config)

  r:get('/status/ready', _M.ready)
  r:get('/status/live', _M.live)

  r:post('/boot', _M.boot)

  return r
end

function _M.call(method, uri, ...)
  local r = _M.router()

  local ok, err = r:execute(method or ngx.req.get_method(),
                                 uri or ngx.var.uri,
                                 unpack(... or {}))

  if not ok then
    ngx.status = 404
  end

  if err then
    ngx.say(err)
  end
end

return _M
