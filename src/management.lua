local _M = {}

local cjson = require('cjson')
local provider = require('provider')

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
  local has_configuration = provider.configured
  local has_services = #(provider.services or {}) > 0

  if not has_configuration then
    return { status = 'error', error = 'not configured',  success = false }
  elseif not has_services then
    return { status = 'warning', warning = 'no services', success = false }
  else
    return { status = 'ready', success = true }
  end
end

function _M.config()
  local config = cjson.encode(provider.contents)

  ngx.status = 200
  ngx.say(config)
end

return _M
