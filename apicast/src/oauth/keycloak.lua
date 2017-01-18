local setmetatable = setmetatable
local len = string.len
local tostring = tostring
local open = io.open
local assert = assert
local sub = string.sub

local util = require 'util'
local cjson = require 'cjson'
local inspect = require 'inspect'

local http_ng = require "resty.http_ng"
local resty_url = require 'resty.url'

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.authorize(self)

  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  -- TODO: check request params and reply with error if something is wrong

  -- TODO: check client_id at 3scale to see if it's valid, reply with error if it's not

  -- call Keycloak authorize
  local url = resty_url.join(self.config.authorize_url,'?', ngx.var.args)

  -- TODO: maybe use the same method the original request uses, not overriding to GET
  local res, err = http_client.get(url)

  -- TODO: is there a better way to populate the response headers?..
  for name,value in pairs(res.headers) do
    ngx.header[name] = value
  end

  ngx.status = res.status
  ngx.print(res.body)
  ngx.exit(ngx.HTTP_OK)
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

  local res, err = http_client.post(url, req_body)
  for name,value in pairs(res.headers) do
    ngx.header[name] = value
  end

  ngx.status = res.status
  ngx.print(res.body)
  ngx.exit(ngx.HTTP_OK)
end

function _M.callback(self)
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

-- TODO: probably there's a better way to do it, but this doesn't need any external libraries
local function format_public_key(key)
  local formatted_key = "-----BEGIN PUBLIC KEY-----\n"
  local len = string.len(key)
  for i=1,len,64 do
    formatted_key = formatted_key..string.sub(key, i, i+63).."\n"
  end
  formatted_key = formatted_key.."-----END PUBLIC KEY-----"
  return formatted_key
end

-- The format of the config file is the following:
--{
--  "type": "keycloak",
--  "server": "http://KEYCLOAK_HOST:8080",  -- TODO: https doesn't work even with ssl verify false, though the certificate should be OK
--  "realm": "REALM_NAME",
--  "initial_access_token": "FOR_CLIENT_REGISTRATION",
--  "public_key": "FOR_VALIDATING_JWT"
--}

function _M.new(config_path)

  local config = parse(config_path)

  local realm_url = resty_url.join(config.server, '/auth/realms/', config.realm)

  local keycloak_config = {
    authorize_url = resty_url.join(realm_url,'/protocol/openid-connect/auth'),
    token_url = resty_url.join(realm_url,'/protocol/openid-connect/token'),
    client_registrations_url = resty_url.join(realm_url,'/clients-registrations/default'),
    initial_access_token = config.initial_access_token,
    public_key = format_public_key(config.public_key)
  }

  local http_client = http_ng.new{
    options = {
      ssl = { verify = false }
    }
  }

  -- TODO: return an error if some settings are not OK

  return setmetatable({
    config = keycloak_config,
    http_client = http_ng.new()
    }, mt)
end

return _M
