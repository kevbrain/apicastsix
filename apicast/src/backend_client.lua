------------
-- Backend Client
-- HTTP client using @{http_ng.HTTP} to call 3scale backend.
--
-- @module backend_client
-- @author mikz
-- @license Apache License Version 2.0

--- Backend Client
-- @type backend_client

local setmetatable = setmetatable
local concat = table.concat
local insert = table.insert
local len = string.len
local format = string.format

local http_ng = require('resty.http_ng')
local user_agent = require('user_agent')
local resty_url = require('resty.url')
local resty_env = require('resty.env')

local _M = {
  endpoint = resty_env.get("BACKEND_ENDPOINT_OVERRIDE")

}

local mt = { __index = _M }

--- Return new instance of backend client
-- @tparam Service service object with service definition
-- @tparam http_ng.backend http_client async/test/custom http backend
-- @treturn backend_client
function _M:new(service, http_client)
  local endpoint = self.endpoint or service.backend.endpoint or error('missing endpoint')
  local service_id = service.id

  if not endpoint then
    ngx.log(ngx.WARN, 'service ', service_id, ' does not have backend endpoint configured')
  end

  local authentication = { service_id = service_id }

  if service.backend_authentication and service.backend_authentication.type then
    authentication[service.backend_authentication.type] = service.backend_authentication.value
  end

  local backend, err = resty_url.split(endpoint)

  if not backend and err then
    return nil, err
  end

  local client = http_ng.new{
    backend = http_client,
    options = {
      headers = {
        user_agent = user_agent(),
        host = service.backend and service.backend.host or backend[4],
      },
      ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') }
    }
  }

  return setmetatable({
    version = service.backend_version,
    endpoint = endpoint,
    service_id = service_id,
    authentication = authentication,
    http_client = client
  }, mt)
end

local function build_args(args)
  local query = {}

  for i=1, #args do
    local arg = ngx.encode_args(args[i])
    if len(arg) > 0 then
      insert(query, arg)
    end
  end

  return concat(query, '&')
end

local function build_url(self, path, ...)
  local endpoint = self.endpoint

  if not endpoint then
    return nil, 'missing endpoint'
  end

  local args = { self.authentication, ... }
  return resty_url.join(endpoint, '', path .. '?' .. build_args(args))
end

local function call_backend_transaction(self, path, options, ...)
  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local url = build_url(self, path, ...)
  local res = http_client.get(url, options)

  ngx.log(ngx.INFO, 'backend client uri: ', url, ' ok: ', res.ok, ' status: ', res.status, ' body: ', res.body)

  return res
end

local function authrep_path(using_oauth)
  return (using_oauth and '/transactions/oauth_authrep.xml') or
         '/transactions/authrep.xml'
end

local function auth_path(using_oauth)
  return (using_oauth and '/transactions/oauth_authorize.xml') or
         '/transactions/authorize.xml'
end

local function create_token_path(service_id)
  return format('/services/%s/oauth_access_tokens.xml', service_id)
end

local authorize_options = {
  headers = {
    ['3scale-options'] =  'rejection_reason_header=1'
  }
}

--- Call authrep (oauth_authrep) on backend.
-- @tparam ?{table,...} query list of query parameters
-- @treturn http_ng.response http response
function _M:authrep(...)
  if not self then
    return nil, 'not initialized'
  end

  local auth_uri = authrep_path(self.version == 'oauth')
  return call_backend_transaction(self, auth_uri, authorize_options, ...)
end

--- Call authorize (oauth_authorize) on backend.
-- @tparam ?{table,...} query list of query parameters
-- @treturn http_ng.response http response
function _M:authorize(...)
  if not self then
    return nil, 'not initialized'
  end

  local auth_uri = auth_path(self.version == 'oauth')
  return call_backend_transaction(self, auth_uri, authorize_options, ...)
end

--- Calls backend to create an oauth token.
-- @tparam ?{table, ...} list of query params (might include the token, ttl,
--   app_id, and user_id)
-- @treturn http_ng.response http response
function _M:store_oauth_token(token_info)
  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local url = build_url(self, create_token_path(self.service_id))
  return http_client.post(url, token_info)
end

return _M
