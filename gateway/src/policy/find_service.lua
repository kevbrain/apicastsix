local next = next

local policy = require('policy')
local _M = policy.new('Find Service Policy')
local configuration_store = require 'configuration_store'
local new = _M.new

local function find_service_strict(configuration, host)
  local found
  local services = configuration:find_by_host(host)

  for s=1, #services do
    local service = services[s]
    local hosts = service.hosts or {}

    for h=1, #hosts do
      if hosts[h] == host and service == configuration:find_by_id(service.id) then
        found = service
        break
      end
    end
    if found then break end
  end

  return found or ngx.log(ngx.WARN, 'service not found for host ', host)
end

local function find_service_cascade(configuration, host)
  local found
  local request = ngx.var.request
  local services = configuration:find_by_host(host)

  for s=1, #services do
    local service = services[s]
    local hosts = service.hosts or {}

    for h=1, #hosts do
      if hosts[h] == host then
        local name = service.system_name or service.id
        ngx.log(ngx.DEBUG, 'service ', name, ' matched host ', hosts[h])
        local usage, matched_patterns = service:extract_usage(request)

        if next(usage) and matched_patterns ~= '' then
          ngx.log(ngx.DEBUG, 'service ', name, ' matched patterns ', matched_patterns)
          found = service
          break
        end
      end
    end
    if found then break end
  end

  return found or find_service_strict(configuration, host)
end

function _M.new(...)
  local self = new(...)

  if configuration_store.path_routing then
    ngx.log(ngx.WARN, 'apicast experimental path routing enabled')
    self.find_service = find_service_cascade
  else
    self.find_service = find_service_strict
  end

  return self
end

function _M:rewrite(context)
  context.service = self.find_service(context.configuration, context.host)
end

return _M
