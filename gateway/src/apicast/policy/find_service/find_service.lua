local configuration_store = require 'apicast.configuration_store'
local host_based_finder = require('apicast.policy.find_service.host_based_finder')
local path_based_finder = require('apicast.policy.find_service.path_based_finder')

local Policy = require('apicast.policy')
local _M = Policy.new('Find Service Policy')

local new = _M.new

function _M.new(...)
  local self = new(...)

  if configuration_store.path_routing then
    ngx.log(ngx.WARN, 'apicast path routing enabled')
    self.find_service = function(configuration, host)
      return path_based_finder.find_service(configuration, host) or
             host_based_finder.find_service(configuration, host)
    end
  else
    self.find_service = host_based_finder.find_service
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
