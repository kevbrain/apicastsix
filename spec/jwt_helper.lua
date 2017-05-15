local busted = require('busted')

local jwt_validators = require 'resty.jwt-validators'
local ngx_now = ngx.now

busted.before_each(function()
  jwt_validators.set_system_clock(ngx_now)
end)

local oidc = require('oauth.oidc')

busted.before_each(oidc.reset)
