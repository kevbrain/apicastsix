local Policy = require('apicast.policy')
local _M = Policy.new('Find Service Policy')
local configuration_store = require 'apicast.configuration_store'
local mapping_rules_matcher = require 'apicast.mapping_rules_matcher'
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
  local services = configuration:find_by_host(host)
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  for s=1, #services do
    local service = services[s]
    local hosts = service.hosts or {}

    for h=1, #hosts do
      if hosts[h] == host then
        local name = service.system_name or service.id
        ngx.log(ngx.DEBUG, 'service ', name, ' matched host ', hosts[h])

        local matches = mapping_rules_matcher.matches(method, uri, {}, service.rules)
        -- matches() also returns the index of the first rule that matched.
        -- As a future optimization, in the part of the code that calculates
        -- the usage, we could use this to avoid trying to match again all the
        -- rules before the one that matched.

        if matches then
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
    ngx.log(ngx.WARN, 'apicast path routing enabled')
    self.find_service = find_service_cascade
  else
    self.find_service = find_service_strict
  end

  return self
end

local function find_service(policy, context)
  context.service = context.service or policy.find_service(context.configuration, context.host)
end

_M.rewrite = find_service

-- ssl_certiticate is the first phase executed when request arrives on HTTPS
-- therefore it needs to find a service to build a policy chain
_M.ssl_certificate = find_service

return _M
