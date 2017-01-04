local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local insert = table.insert

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new()
  return setmetatable({
    services = {},
    hosts = {}
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

function _M.find(self, host)
  local hosts = self.hosts
  local all = self.services

  if not hosts or not all then
    return nil, 'not initialized'
  end

  local exact_match = all[tostring(host)]

  if exact_match then
    return { exact_match }
  end

  return hosts[host] or { }
end

function _M.store(self, config)
  self.configured = true

  for _,service in ipairs(config.services) do
    _M.add(self, service)
  end

  return config
end

function _M.reset(self)
  if not self then
    return nil, 'not initialized'
  end

  self.services = {}
  self.hosts = {}
  self.configured = false
end

function _M.add(self, service)
  local hosts = self.hosts
  local all = self.services

  if not hosts or not all then
    return nil, 'not initialized'
  end

  for _,host in ipairs(service.hosts) do
    local index = hosts[host] or {}
    local id = tostring(service.id)

    index[id] = service
    all[id] = service
    hosts[host] = index
  end
end

return _M
