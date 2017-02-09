local env = require 'resty.env'
local router = require 'router'
local oauth

local _M = {
  _VERSION = '0.0.2'
}

function _M.new()
  local keycloak = env.get('RHSSO_ENDPOINT')
  if keycloak then 
    oauth = require 'oauth.keycloak'
    local public_key = env.get('RHSSO_PUBLIC_KEY')
    oauth.init(keycloak, public_key)
  else
    oauth = require 'oauth.apicast_oauth'
  end
  return oauth.new()
end

function _M.router()
  -- TODO: use configuration to customize urls
  local r = router:new()

  local oauth = _M.new()

  r:get('/authorize', function() oauth:authorize() end)
  r:post('/authorize', function() oauth:authorize() end)

  -- TODO: only applies to apicast oauth...
  r:post('/callback', function() oauth:callback() end)
  r:get('/callback', function() oauth:callback() end)

  r:post('/oauth/token', function() oauth:get_token() end)

  return r
end

function _M.call(method, uri, ...)
  local r = _M.router()

  local f, params = r:resolve(method or ngx.req.get_method(),
    uri or ngx.var.uri,
    unpack(... or {}))

  return f, params
end

return _M
