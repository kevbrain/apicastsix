local apicast_oauth = require 'apicast.oauth.apicast_oauth'
local oidc = require 'apicast.oauth.oidc'

local _M = {
  _VERSION = '0.0.2',

  apicast = apicast_oauth,
  oidc = oidc,
}

return _M
