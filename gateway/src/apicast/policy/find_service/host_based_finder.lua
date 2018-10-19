local _M = {}

function _M.find_service(config_store, host)
  local found
  local services = config_store:find_by_host(host)

  for s=1, #services do
    local service = services[s]
    local hosts = service.hosts or {}

    for h=1, #hosts do
      if hosts[h] == host and service == config_store:find_by_id(service.id) then
        found = service
        break
      end
    end
    if found then break end
  end

  return found or ngx.log(ngx.WARN, 'service not found for host ', host)
end

return _M
