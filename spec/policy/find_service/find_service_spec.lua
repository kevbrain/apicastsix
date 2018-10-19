local FindService = require('apicast.policy.find_service')
local ConfigurationStore = require('apicast.configuration_store')
local configuration = require('apicast.configuration')

describe('find_service', function()
  describe('.rewrite', function()
    describe('when path routing is enabled', function()
      it('finds the service by matching rules and stores it in the given context', function()
        ConfigurationStore.path_routing = true

        -- We access ngx.var.uri, ngx.req.get_method, and ngx.req.get_uri_args
        -- directly in the code, so we need to mock them. We should probably
        -- try to avoid this kind of coupling.
        ngx.var = { uri = '/def' }
        stub(ngx.req, 'get_uri_args', function() return {} end)
        stub(ngx.req, 'get_method', function() return 'GET' end)

        local find_service_policy = FindService.new()
        local host = 'example.com'

        local service_1 = configuration.parse_service({
          id = 42,
          proxy = {
            hosts = { host },
            proxy_rules = { { pattern = '/abc', http_method = 'GET',
                              metric_system_name = 'hits', delta = 1 } }
          }
        })

        local service_2 = configuration.parse_service({
          id = 43,
          proxy = {
            hosts = { host },
            proxy_rules = { { pattern = '/def', http_method = 'GET',
                              metric_system_name = 'hits', delta = 2 } }
          }
        })

        local service_3 = configuration.parse_service({
          id = 44,
          proxy = {
            hosts = { host },
            proxy_rules = { { pattern = '/ghi', http_method = 'GET',
                              metric_system_name = 'hits', delta = 3 } }
          }
        })

        local configuration_store = ConfigurationStore.new()
        configuration_store:store(
          { services = { service_1, service_2, service_3 } })

        local context = { host = host, configuration = configuration_store }
        find_service_policy:rewrite(context)

        assert.equal(service_2, context.service)
      end)

      describe('and no rules are matched', function()
        it('finds a service for the host in the context and stores the service there', function()
          ConfigurationStore.path_routing = true
          ngx.var = { uri = '/abc' }

          stub(ngx.req, 'get_uri_args', function() return {} end)
          stub(ngx.req, 'get_method', function() return 'GET' end)

          local host = 'example.com'
          local find_service_policy = FindService.new()

          local service = configuration.parse_service({
            id = 42,
            proxy = {
              hosts = { host },
              proxy_rules = { { pattern = '/', http_method = 'GET',
                                metric_system_name = 'hits', delta = 1 } }
            }
          })

          local configuration_store = ConfigurationStore.new()
          configuration_store:add(service)

          local context = { host = host, configuration = configuration_store }

          find_service_policy:rewrite(context)
          assert.same(service, context.service)
        end)
      end)

      describe('and no rules are matched and there is not a service for the host', function()
        it('stores nil in the service field of the given context', function()
          ConfigurationStore.path_routing = true
          ngx.var = { uri = '/abc' }
          stub(ngx.req, 'get_uri_args', function() return {} end)
          stub(ngx.req, 'get_method', function() return 'GET' end)

          local find_service_policy = FindService.new()
          local configuration_store = ConfigurationStore.new()

          local context = {
            host = 'example.com',
            configuration = configuration_store
          }

          find_service_policy:rewrite(context)
          assert.is_nil(context.service)
        end)
      end)
    end)

    describe('when path routing is disabled', function()
      ConfigurationStore.path_routing = false

      it('finds the service of the host in the given context and stores it there', function()
        local find_service_policy = FindService.new()

        local host = 'example.com'
        local service = configuration.parse_service({
          id = 42,
          proxy = {
            hosts = { host },
            proxy_rules = { { pattern = '/', http_method = 'GET',
                              metric_system_name = 'hits', delta = 1 } }
          }
        })
        local configuration_store = ConfigurationStore.new()
        configuration_store:add(service)

        local context = { host = host, configuration = configuration_store }
        find_service_policy:rewrite(context)
        assert.same(service, context.service)
      end)

      describe('and there is not a service for the host', function()
        it('stores nil in the service field of the given context', function()
          local find_service_policy = FindService.new()
          local configuration_store = ConfigurationStore.new()

          local context = {
            host = 'example.com',
            configuration = configuration_store
          }

          find_service_policy:rewrite(context)
          assert.is_nil(context.service)
        end)
      end)
    end)
  end)
end)
