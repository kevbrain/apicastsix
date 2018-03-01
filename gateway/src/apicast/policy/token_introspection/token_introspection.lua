local policy = require('apicast.policy')
local _M = policy.new('Token Introspection Policy')

local cjson = require('cjson')
local http_authorization = require 'resty.http_authorization'
local http_ng = require 'resty.http_ng'
local user_agent = require 'apicast.user_agent'
local resty_env = require('resty.env')

local new = _M.new

function _M.new(config)
  local self = new()
  self.config = config or {}
  --- authorization for the token introspection endpoint.
  -- https://tools.ietf.org/html/rfc7662#section-2.2
  local credential = 'Basic ' .. ngx.encode_base64(table.concat({ self.config.client_id or '', self.config.client_secret or '' }, ':'))
  self.introspection_url = config.introspection_url
  self.http_client = http_ng.new{
    backend = config.client,
    options = {
      headers = { 
        ['User-Agent'] = user_agent(),
        ['Authorization'] = credential
      },
      ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') }
    }
  }
  return self
end

--- OAuth 2.0 Token Introspection defined in RFC7662.
-- https://tools.ietf.org/html/rfc7662
local function introspect_token(self, token)
  --- Parameters for the token introspection endpoint.
  -- https://tools.ietf.org/html/rfc7662#section-2.1
  local res, err = self.http_client.post(self.introspection_url , { token = token, token_type_hint = 'access_token'})
  if res and err then
    ngx.log(ngx.WARN, 'token introspection error: ', err, ' url: ', self.introspection_url)
    return { active = false }
  end

  if res.status == 200 then
    local token_info = cjson.decode(res.body)
    return token_info
  else
    ngx.log(ngx.WARN, 'failed to execute token introspection. status: ', res.status)
    return { active = false }
  end
end

function _M:access(context)
  if self.introspection_url then
    local authorization = http_authorization.new(ngx.var.http_authorization)
    local access_token = authorization.token
    --- Introspection Response must have an "active" boolean value.
    -- https://tools.ietf.org/html/rfc7662#section-2.2
    if not introspect_token(self, access_token).active then
      ngx.status = context.service.auth_failed_status
      ngx.say(context.service.error_auth_failed)
      return ngx.exit(ngx.status)
    end
  end
end

return _M
