local setmetatable = setmetatable
local pairs = pairs
local insert = table.insert
local concat = table.concat
local rawset = rawset

local env = require 'resty.env'

local _M = {
  _VERSION = '0.1',
  path_routing = env.enabled('APICAST_PATH_ROUTING_ENABLED')
}

local mt = { __index = _M }

function _M.new()
  return setmetatable({
    -- services hashed by id, example: {
    --   ["16"] = service1
    -- }
    services = {},

    -- hash of hosts pointing to services, example: {
    --  ["host.example.com"] = {
    --    { service1 },
    --    { service2 }
    --  }
    cache = {}

  }, mt)
end

function _M.all(self)
  local all = self.services
  local services = {}

  if not all then
    return nil, 'not initialized'
  end

  for _,service in pairs(all) do
    insert(services, service.serializable or service)
  end

  return services
end

function _M.find_by_id(self, service_id)
  local all = self.services

  if not all then
    return nil, 'not initialized'
  end

  return all[service_id]
end

function _M.find_by_host(self, host)
  local cache = self.cache
  if not cache then
    return nil, 'not initialized'
  end

  return cache[host] or { }
end

local hashed_array = {
  __index = function(t,k)
    local v = {}
    rawset(t,k, v)
    return v
  end
}

function _M.store(self, config)
  self.configured = true

  local services = config.services
  local by_host = setmetatable({}, hashed_array)

  for i=1, #services do
    local hosts = services[i].hosts or {}
    local id = services[i].id

    ngx.log(ngx.INFO, 'added service ', id, ' configuration with hosts: ', concat(hosts, ', '))

    for j=1, #hosts do
      local h = by_host[hosts[j]]

      if #(h) == 0 or _M.path_routing then
        insert(h, services[i])
      else
        ngx.log(ngx.WARN, 'skipping host ', hosts[j], ' for service ', id, ' already defined by service ', h[1].id)
      end
    end

    self.services[id] = services[i]
  end

  local cache = self.cache

  for host, services in pairs(by_host) do
    cache[host] = services
  end

  return config
end

function _M.reset(self)
  if not self then
    return nil, 'not initialized'
  end

  self.services = {}
  self.cache = {}
  self.configured = false
end

function _M.add(self, service)
  if not self.services then
    return nil, 'not initialized'
  end

  return self:store({ services = { service }})
end

return _M
