local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local insert = table.insert
local concat = table.concat
local next = next

local env = require 'resty.env'

local _M = {
  _VERSION = '0.1',
  path_routing = env.enabled('APICAST_PATH_ROUTING_ENABLED')
}

local mt = { __index = _M }

function _M.new()
  return setmetatable({
    services = {},
    hosts = {},
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

function _M.store(self, config)
  self.configured = true
  local services = config.services

  for i = 1, #services do
    _M.add(self, services[i])
  end

  return config
end

function _M.reset(self)
  if not self then
    return nil, 'not initialized'
  end

  self.services = {}
  self.hosts = {}
  self.cache = {}
  self.configured = false
end

function _M.add(self, service)
  local hosts = self.hosts
  local all = self.services
  local cache = self.cache

  if not hosts or not all then
    return nil, 'not initialized'
  end

  local id = service.id

  if not service.hosts then
    ngx.log(ngx.WARN, 'service ', id, ' is missing hosts')
    return
  end

  for _,host in ipairs(service.hosts) do
    local index = hosts[host] or {}
    local exists = not _M.path_routing and next(index)

    -- already exists in cache
    local pos = index[id]
    local c = cache[host] or {}

    if pos then
      c[pos] = service
    else
      insert(c, service)
      index[id] = #c
      all[id] = service
    end

    cache[host] = c
    hosts[host] = index

    if exists and exists ~= id then
      ngx.log(ngx.WARN, 'host ', host, ' for service ', id, ' already defined by service ', exists)
    end
  end

  ngx.log(ngx.INFO, 'added service ', id, ' configuration with hosts: ', concat(service.hosts, ', '))
end

return _M
