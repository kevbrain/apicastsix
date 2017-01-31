local setmetatable = setmetatable
local len = string.len
local tostring = tostring
local open = io.open
local assert = assert
local sub = string.sub

local util = require 'util'
local cjson = require 'cjson'
local http_ng = require "resty.http_ng"
local resty_url = require 'resty.url'
local inspect = require 'inspect'
local jwt = require 'resty.jwt'
local resty_env = require 'resty.env'

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

function _M.init(config)
  _M.configured = true
  _M.configuration = config
end

function _M.new(config, url)
  local endpoint = url or resty_env.get('RHSSO_ENDPOINT')
  ngx.log(0, inspect(endpoint))
  local configuration = config or _M.configuration

  if not configuration then
    ngx.log(ngx.ERR,'Keycloak is not configured')
    return nil
  end

  -- TODO: return an error if some settings are not OK

  local config = configuration

  -- local realm_url = resty_url.join(config.server, '/auth/realms/', config.realm)

  local keycloak_config = {
    authorize_url = resty_url.join(endpoint,'/protocol/openid-connect/auth'),
    token_url = resty_url.join(endpoint,'/protocol/openid-connect/token'),
    client_registrations_url = resty_url.join(endpoint,'/clients-registrations/default'),
    initial_access_token = config.initial_access_token,
    public_key = util.format_public_key(config.public_key)
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

  -- call Keycloak authorize
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

local pwd

-- TODO: extract this function (initially from the 'configuration_loader.file') to some common
local function read(path)
  if not path or len(tostring(path)) == 0 then
    return nil, 'missing path'
  end

  local relative_path = sub(path, 1, 1) ~= '/'
  local absolute_path

  if relative_path then
    pwd = pwd or util.system('pwd')
    absolute_path =  sub(pwd, 1, len(pwd) - 1) .. '/' .. path
  else
    absolute_path = path
  end
  return assert(open(absolute_path)):read('*a'), absolute_path
end

local function parse(config_path)
  local conf = read(config_path)
  return cjson.decode(conf)
end

-- The format of the config file is the following:
--{
--  "type": "keycloak",
--  "server": "http://KEYCLOAK_HOST:8080",
--  "realm": "REALM_NAME",
--  "initial_access_token": "FOR_CLIENT_REGISTRATION",
--  "public_key": "FOR_VALIDATING_JWT"
--}

return _M
