local get_token = require 'get_token'
local callback = require 'authorized_callback'
local authorize = require 'authorize'

local router = require 'router'

local _M = {
  version = '0.0.1'
}

function _M.router()
  -- TODO: use configuration to customize urls
  local r = router:new()

  r:get('/authorize', authorize.call)
  r:post('/authorize', authorize.call)

  r:post('/callback', callback.call)
  r:get('/callback', callback.call)

  r:post('/oauth/token', get_token.call)

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


