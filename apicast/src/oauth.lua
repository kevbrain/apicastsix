local env = require 'resty.env'
local apicast_oauth = require 'oauth.apicast_oauth'
local keycloak = require 'oauth.keycloak'

local router = require 'router'
local inspect = require 'inspect'
local setmetatable = setmetatable

local _M = {
  _VERSION = '0.0.2'
}

function _M.new()
  local oauth
  local custom_openid = env.get('OPENID_CONFIG')
  if not custom_openid or custom_openid == '' then
    oauth = apicast_oauth.new()
  else
    oauth = keycloak.new(custom_openid)
  end
  return oauth
end

function _M.router()
  -- TODO: use configuration to customize urls
  local r = router:new()

  local oauth = _M.new()

  r:get('/authorize', function(params) oauth:authorize() end)
  r:post('/authorize', function(params) oauth:authorize() end)

  -- TODO: only applies to apicast oauth...
  r:post('/callback', function(params) oauth:callback() end)
  r:get('/callback', function(params) oauth:callback() end)

  r:post('/oauth/token', function(params) oauth:get_token() end)

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
