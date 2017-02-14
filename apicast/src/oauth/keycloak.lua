local setmetatable = setmetatable
local len = string.len
local http_ng = require "resty.http_ng"
local resty_url = require 'resty.url'
local jwt = require 'resty.jwt'

local _M = {
  _VERSION = '0.1'
}
local mt = {
  __index = _M
}

-- Required params for each grant type and response type.
_M.params = {
  grant_type = {
    ['authorization_code'] = {'client_id','redirect_uri','code'},
    ['password'] = {'client_id','client_secret','username','password'},
    ['client_credentials'] = {'client_id','client_secret'}
  },
  response_type = {
    ['code'] = {'client_id','redirect_uri'},
    ['token'] = {'client_id','redirect_uri'}
  }
}

function _M.init(endpoint, public_key)
  _M.configured = endpoint and public_key

  local config = { endpoint = endpoint, public_key = public_key }
  if _M.configured then
    _M.configuration = config
  end
end

local function format_public_key(key)
  if not key then
    return nil, 'missing key'
  end

  local formatted_key = "-----BEGIN PUBLIC KEY-----\n"
  local key_len = len(key)
  for i=1,key_len,64 do
    formatted_key = formatted_key..string.sub(key, i, i+63).."\n"
  end
  formatted_key = formatted_key.."-----END PUBLIC KEY-----"
  return formatted_key
end

function _M.new(config)
  local configuration = config or _M.configuration
  -- TODO: return an error if some settings are not OK

  if not configuration then
    ngx.log(ngx.ERR,'Keycloak is not configured')
    return nil
  end

  local keycloak_config = {
    endpoint = configuration.endpoint,
    authorize_url = resty_url.join(configuration.endpoint,'/protocol/openid-connect/auth'),
    token_url = resty_url.join(configuration.endpoint,'/protocol/openid-connect/token'),
    public_key = format_public_key(configuration.public_key)
  }

  local http_client = http_ng.new{
    backend = configuration.client,
    options = {
      ssl = { verify = false }
    }
  }

  return setmetatable({
    config = keycloak_config,
    http_client = http_client
    }, mt)
end

function _M.respond_and_exit(status, body, headers)
  -- TODO: is there a better way to populate the response headers?..
  if headers then
    for name,value in pairs(headers) do
      ngx.header[name] = value
    end
  end

  ngx.status = status
  ngx.print(body)
  ngx.exit(ngx.HTTP_OK)
end

function _M.respond_with_error(status, message)
  local headers = {
    ['Content-Type'] = 'application/json;charset=UTF-8'
  }
  local body = '{"error":"'..message..'"}"'
  _M.respond_and_exit(status, body, headers)
end

function _M.authorize_check_params(params)
  local response_type = params['response_type']
  local required_params = _M.params.response_type
  if not response_type then return false, 'invalid_request' end
  if not required_params[response_type] then return false, 'unsupported_response_type' end

  for _,v in ipairs(required_params[response_type]) do
    if not params[v] then
      return false, 'invalid_request'
    end
  end

  
  return true
end

function _M.token_check_params(params)
  local grant_type = params['grant_type']
  local required_params = _M.params.grant_type
  if not grant_type then return false, 'invalid_request' end
  if not required_params[grant_type] then return false, 'unsupported_grant_type' end

  for _,v in ipairs(required_params[grant_type]) do
    if not params[v] then
      return false, 'invalid_request'
    end
  end
  return true
end

-- Parses the token - in this case we assume it's a JWT token
-- Here we can extract authenticated user's claims or other information returned in the access_token
-- or id_token by RH SSO
function _M.parse_and_verify_token(jwt_token, public_key)
  local jwt_obj = jwt:verify(public_key, jwt_token)
  if not jwt_obj.verified then
    ngx.log(ngx.INFO, "[jwt] failed verification for token: "..jwt_token)
  end
  return jwt_obj
end

function _M.check_client_id(client_id)
  -- make a call to 3scale to verify the credentials
  return true
end

function _M.authorize(self)

  local ok, err
  local params = ngx.req.get_uri_args()
  ok, err = _M.authorize_check_params(params)

  if err then
    _M.respond_with_error(400, err)
  end

  -- TODO: check client_id at 3scale to see if it's valid, reply with error if it's not
  local client_id = params.client_id
  ok, err = _M.check_client_id(client_id)
  if err then
    _M.respond_with_error(401, 'invalid_client')
  end

  local url = resty_url.join(self.config.authorize_url, ngx.var.is_args, ngx.var.args)
  local http_client = self.http_client
  local res = http_client.get(url)

  _M.respond_and_exit(res.status, res.body, res.headers)
end

function _M.get_token(self)

  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  -- TODO: check request params and reply with error if something is wrong

  -- TODO: check client_id at 3scale to see if it's valid, reply with error if it's not

  -- call Keycloak authorize
  local url = self.config.token_url

  -- TODO: maybe use the same method the original request uses
  ngx.req.read_body()
  local req_body = ngx.req.get_post_args()

  local res = http_client.post(url, req_body)

  _M.respond_and_exit(res.status, res.body, res.headers)
end

function _M.callback()
  return
end

return _M
