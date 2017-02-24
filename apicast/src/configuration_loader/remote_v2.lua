local setmetatable = setmetatable
local format = string.format
local ipairs = ipairs
local insert = table.insert

local resty_url = require 'resty.url'
local http_ng = require "resty.http_ng"
local user_agent = require 'user_agent'
local cjson = require 'cjson'
local resty_env = require 'resty.env'

local _M = {
  _VERSION = '0.1'
}
local mt = {
  __index = _M
}

function _M.new(url, options)
  local endpoint = url or resty_env.get('THREESCALE_PORTAL_ENDPOINT')
  local opts = options or {}

  local http_client = http_ng.new{
    backend = opts.client,
    options = {
      headers = { ['User-Agent'] = user_agent() },
      ssl = { verify = false }
    }
  }

  return setmetatable({
    endpoint = endpoint,
    options = opts,
    http_client = http_client
  }, mt)
end

function _M:call(environment)
  if not self then
    return _M.new():call()
  end

  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local env = environment or resty_env.get('THREESCALE_DEPLOYMENT_ENV')
  if not env then
    return nil, 'missing environment'
  end
  local configs = {}

  local res, err = self:services()

  if not res and err then
    return nil, err
  end

  for _, object in ipairs(res) do
    insert(configs, ngx.thread.spawn(self.config, self, object.service, env, 'latest'))
  end

  for i, c in ipairs(configs) do
    local ok, ret = ngx.thread.wait(c)

    if ok then
      configs[i] = ret and ret.content or nil
    else
      configs[i] = nil
      ngx.log(ngx.WARN, 'failed to download configuration: ', ret)
    end
  end

  return cjson.encode({ services = configs })
end

function _M:services()
  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local url = resty_url.join(self.endpoint, '/admin/api/services.json')

  local res, err = http_client.get(url)

  if not res and err then
    return nil, err
  end

  if res.status == 200 then
    local json = cjson.decode(res.body)

    return json.services
  else
    return nil, 'invalid status'
  end
end

function _M:config(service, environment, version)
  local http_client = self.http_client

  if not http_client then return nil, 'not initialized' end

  local id = service and service.id

  if not id then return nil, 'invalid service, missing id' end
  if not environment then return nil, 'missing environment' end
  if not version then return nil, 'missing version' end

  local url = resty_url.join(self.endpoint, '/admin/api/services/', id , '/proxy/configs/', environment, '/', format('%s.json', version))

  ngx.log(ngx.INFO, 'downloading configuration from: ', url)

  local res, err = http_client.get(url)

  if not res and err then
    ngx.log(ngx.WARN, 'could not get configuration for service ', id, ': ', err)
    return nil, err
  end

  if res.status == 200 then
    local json = cjson.decode(res.body)

    return json.proxy_config
  else
    ngx.log(ngx.WARN, 'could not get configuration for service ', id, ': status ', res.status, ' != 200')
    return nil, 'invalid status'
  end
end


return _M
