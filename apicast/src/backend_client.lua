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

local http_ng = require('resty.http_ng')
local user_agent = require('user_agent')
local resty_url = require('resty.url')
local resty_env = require('resty.env')

local _M = {

}

local mt = { __index = _M }

--- Return new instance of backend client
-- @tparam Service service object with service definition
-- @tparam http_ng.backend http_client async/test/custom http backend
-- @treturn backend_client
function _M.new(_, service, http_client)
  local endpoint = service.backend.endpoint or ngx.var.backend_endpoint
  local service_id = service.id

  if not endpoint then
    ngx.log(ngx.WARN, 'service ', service_id, ' does not have backend endpoint configured')
  end

  local authentication = { service_id = service_id }

  if service.backend_authentication.type then
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
        host = service.backend.host or backend[4]
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

local function call_backend_transaction(self, path, ...)
  local version = self.version
  local http_client = self.http_client

  if not version or not http_client then
    return nil, 'not initialized'
  end

  local endpoint = self.endpoint

  if not endpoint then
    return nil, 'missing endpoint'
  end


  local args = { self.authentication, ... }

  for i=1, #args do
    args[i] = ngx.encode_args(args[i])
  end

  local url = resty_url.join(endpoint, '/transactions', path .. '?' .. concat(args, '&'))

  local res = http_client.get(url)

  ngx.log(ngx.INFO, 'backend client uri: ', url, ' ok: ', res.ok, ' status: ', res.status, ' body: ', res.body)

  return res
end

--- Call authrep (oauth_authrep) on backend.
-- @tparam ?{table,...} query list of query parameters
-- @treturn http_ng.response http response
function _M:authrep(...)
  if not self then
    return nil, 'not initialized'
  end

  local auth_uri = self.version == 'oauth' and 'oauth_authrep.xml' or 'authrep.xml'
  return call_backend_transaction(self, auth_uri, ...)
end

--- Call authorize (oauth_authorize) on backend.
-- @tparam ?{table,...} query list of query parameters
-- @treturn http_ng.response http response
function _M:authorize(...)
  if not self then
    return nil, 'not initialized'
  end

  local auth_uri = self.version == 'oauth' and 'oauth_authorize.xml' or 'authorize.xml'
  return call_backend_transaction(self, auth_uri, ...)
end

return _M
