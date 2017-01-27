local apicast_oauth = require 'oauth.apicast_oauth'
local keycloak = require 'oauth.keycloak'

local router = require 'router'

local _M = {
  _VERSION = '0.0.2'
}

function _M.new()
  local oauth
  if keycloak.configured then
    oauth = keycloak.new()
  else
    oauth = apicast_oauth.new()
  end
  return oauth
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
