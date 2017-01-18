local get_token = require 'oauth.apicast_oauth.get_token'
local callback = require 'oauth.apicast_oauth.authorized_callback'
local authorize = require 'oauth.apicast_oauth.authorize'
local setmetatable = setmetatable

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new()
  return setmetatable(
    {
      authorize = authorize.call,
      callback = callback.call,
      get_token = get_token.call
    }, mt)
end

return _M
