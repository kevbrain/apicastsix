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
  self.http_client = http_ng.new{
    backend = config.client,
    options = {
      header = { ['User-Agent'] = user_agent() },
      ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') }
    }
  }
  return self
end

local function introspect_token(self, token)
  local config = self.config
  if not config then
    return false
  end

  local introspection_url = config.introspection_url
  local client = config.client_id
  local secret = config.client_secret
  local credential = 'Basic ' .. ngx.encode_base64(table.concat({ client or '', secret or '' }, ':'))
  local opts = {
    headers = {
      ['Authorization'] = credential
    }
  }

  local res, err = self.http_client.post(introspection_url , { token = token, token_type_hint = 'access_token'}, opts)
  if res and err then
    ngx.log(ngx.WARN, 'token introspection error: ', err, ' url: ', introspection_url)
    return false
  end

  if res.status == 200 then
    local token_info = cjson.decode(res.body)
    return token_info.active
  else
    ngx.log(ngx.WARN, 'failed to execute token introspection. status: ', res.status)
    return false
  end
end

function _M:access(context)
  if self.config.introspection_url then
    local authorization = http_authorization.new(ngx.var.http_authorization)
    local access_token = authorization.token
    if not introspect_token(self, access_token) then
      ngx.status = context.service.auth_failed_status
      ngx.say(context.service.error_auth_failed)
      return ngx.exit(ngx.status)
    end
  end
end

return _M
