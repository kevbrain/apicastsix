local resty_resolver = require 'resty.resolver'
local round_robin = require 'resty.balancer.round_robin'

local setmetatable = setmetatable

local _M = {}
local mt = {}

function mt.__index(t,k)
  return _M[k] or t.socket[k]
end

function _M.new(socket)
  if not socket then
    return nil, 'missing socket'
  end

  if not socket.connect then
    return nil, 'socket missing connect'
  end

  return setmetatable({
    socket = socket,
    resolver = resty_resolver:instance(),
    balancer = round_robin.new()
  }, mt)
end

function _M.connect(self, host, port)
  local resolver = self.resolver
  local balancer = self.balancer
  local socket = self.socket

  if not resolver or not balancer or not socket then
    return nil, 'not initialized'
  end

  local servers = resolver:get_servers(host, { port = port })
  local peers = balancer:peers(servers)
  local peer = balancer:select_peer(peers)

  local ip = host

  if peer then
    ip = peer[1]
    port = peer[2]
  end

  local ok, err = socket:connect(ip, port)

  self.host = host
  self.port = port

  return ok, err
end

return _M
