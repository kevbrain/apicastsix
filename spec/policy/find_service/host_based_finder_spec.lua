local HostBasedFinder = require('apicast.policy.find_service.host_based_finder')
local ConfigurationStore = require('apicast.configuration_store')
local Configuration = require('apicast.configuration')

describe('HostBasedFinder', function()
  describe('.find_service', function()
    it('returns the service in the config for the given host', function()
      local host = 'example.com'

      local service_for_host = Configuration.parse_service({
        id = 1,
        proxy = {
          hosts = { host },
          proxy_rules = { { pattern = '/', http_method = 'GET',
                            metric_system_name = 'hits', delta = 1 } }
        }
      })

      local service_different_host = Configuration.parse_service({
        id = 2,
        proxy = {
          hosts = { 'different_host.something' },
          proxy_rules = { { pattern = '/', http_method = 'GET',
                            metric_system_name = 'hits', delta = 1 } }
        }
      })

      local services = { service_for_host, service_different_host }
      local config_store = ConfigurationStore.new()
      config_store:store({ services = services })

      local found_service = HostBasedFinder.find_service(config_store, host)

      assert.same(service_for_host, found_service)
    end)

    it('returns nil if there is not a service for the host', function()
      local host = 'example.com'

      local service_different_host = Configuration.parse_service({
        id = 1,
        proxy = {
          hosts = { 'different_host.something' },
          proxy_rules = { { pattern = '/', http_method = 'GET',
                            metric_system_name = 'hits', delta = 1 } }
        }
      })

      local config_store = ConfigurationStore.new()
      config_store:store({ services = { service_different_host } })

      local found_service = HostBasedFinder.find_service(config_store, host)

      assert.is_nil(found_service)
    end)
  end)
end)
