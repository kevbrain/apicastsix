local get_token = require 'oauth.apicast_oauth.get_token'
local callback = require 'oauth.apicast_oauth.authorized_callback'
local authorize = require 'oauth.apicast_oauth.authorize'
local setmetatable = setmetatable

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(service)
  return setmetatable(
    {
      authorize = authorize.call,
      callback = callback.call,
      get_token = get_token.call,
      service = service
    }, mt)
end

function _M.credentials( access_token )
    ------
    -- oauth credentials.
    -- @field 1 Access Token
    -- @field access_token Access Token
    -- @table credentials_oauth
    return { access_token, access_token = access_token }
end

return _M
