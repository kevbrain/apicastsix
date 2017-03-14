local env = require 'resty.env'
local router = require 'router'
local apicast_oauth = require 'oauth.apicast_oauth'
local keycloak = require 'oauth.keycloak'

local keycloak_configured = env.get('RHSSO_ENDPOINT')
local oauth

local _M = {
  _VERSION = '0.0.2'
}

function _M.new(service)
  if keycloak_configured then
    oauth = keycloak
    oauth.init(keycloak_configured)
  else
    oauth = apicast_oauth
  end
  return oauth.new(service)
end

function _M.router(service)
  -- TODO: use configuration to customize urls
  local r = router:new()
  oauth = _M.new(service)
  r:get('/authorize', function() oauth:authorize() end)
  r:post('/authorize', function() oauth:authorize() end)

  -- TODO: only applies to apicast oauth...
  r:post('/callback', function() oauth:callback() end)
  r:get('/callback', function() oauth:callback() end)

  r:post('/oauth/token', function() oauth:get_token() end)

  return r
end

function _M.call(service, method, uri, ...)
  local r = _M.router(service)

  local f, params = r:resolve(method or ngx.req.get_method(),
    uri or ngx.var.uri,
    unpack(... or {}))

  return f, params
end

function _M.credentials(access_token)
  if keycloak_configured then
    oauth = keycloak
  else
    oauth = apicast_oauth
  end
  return oauth.credentials(access_token)
end

return _M
