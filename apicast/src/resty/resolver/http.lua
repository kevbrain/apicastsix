local resty_http = require 'resty.http'
local resty_resolver = require 'resty.resolver'
local round_robin = require 'resty.balancer.round_robin'

local setmetatable = setmetatable
local unpack = unpack

local _M = setmetatable({}, { __index = resty_http })

local mt = { __index = _M }

function _M.new()
  local http = resty_http:new()

  http.resolver = resty_resolver:instance()
  http.balancer = round_robin.new()

  return setmetatable(http, mt)
end

function _M.connect(self, host, port)
  local resolver = self.resolver
  local balancer = self.balancer

  if not resolver or not balancer then
    return nil, 'not initialized'
  end

  local servers = resolver:get_servers(host, { port = port })
  local peers = balancer:peers(servers)
  local peer = balancer:select_peer(peers)

  local ip = host

  if peer then
    ip, port = unpack(peer)
  end

  local ok, err = resty_http.connect(self, ip, port)

  self.host = host

  return ok, err
end

return _M
