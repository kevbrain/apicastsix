local router = require 'router'
local apicast_oauth = require 'oauth.apicast_oauth'
local keycloak = require 'oauth.keycloak'

local _M = {
  _VERSION = '0.0.2'
}

function _M.new(configuration)
  if configuration.keycloak then
    ngx.log(ngx.INFO, "keycloak configured")
    return keycloak.new(configuration.keycloak)
  else
    return apicast_oauth.new()
  end
end

function _M.router(oauth, service)
  local r = router:new()
  r:get('/authorize', function() oauth:authorize(service) end)
  r:post('/authorize', function() oauth:authorize(service) end)

  -- TODO: only applies to apicast oauth...
  r:post('/callback', function() oauth:callback() end)
  r:get('/callback', function() oauth:callback() end)

  r:post('/oauth/token', function() oauth:get_token(service) end)

  return r
end

function _M.call(oauth, service, method, uri, ...)
  local r = _M.router(oauth, service)

  local f, params = r:resolve(method or ngx.req.get_method(),
    uri or ngx.var.uri,
    unpack(... or {}))

  return f, params
end

return _M
