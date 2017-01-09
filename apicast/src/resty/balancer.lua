local setmetatable = setmetatable
local ipairs = ipairs
local unpack = unpack
local insert = table.insert
local tonumber = tonumber

local ngx_balancer = require "ngx.balancer"

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(mode)
  if not mode then
    return nil, 'missing balancing function'
  end

  return setmetatable({
    mode = mode,
    balancer = ngx_balancer
  }, mt)
end

local function new_peer(server, port)
  local address = server.address

  if not address then
    return nil, 'server missing address'
  end

  return {
    address,
    tonumber(server.port or port or 80, 10)
  }
end

local function convert_servers(servers, port)
  local peers = {}
  local query = servers.query

  for _, server in ipairs(servers) do
    local peer = new_peer(server, port)

    if peer and #peer == 2 then
      insert(peers, peer)
    else
      ngx.log(ngx.INFO, 'skipping peer because it misses address or port')
    end
  end

  if query then
    peers.hash = ngx.crc32_short(query)
  end

  peers.servers = servers

  return peers
end

function _M.peers(_, servers, port)
  if not servers then
    return nil, 'missing servers'
  end

  local peers, err = convert_servers(servers, port)

  return peers, err
end

function _M.set_peer(self, peers)
  local mode = self.mode
  local balancer = self.balancer

  local address, port, peer, ok, err

  if not mode then
    return nil, 'not initialized'
  end

  if not balancer then
    return nil, 'balancer not available'
  end

  if not peers then
    return nil, 'missing peers'
  end

  peer, err = mode(peers)

  if not peer then
    return nil, err or 'no peer found'
  end

  address, port = unpack(peer)

  if not address or not port then
    return nil, 'peer missing address or port'
  end

  ngx.log(ngx.INFO, 'balancer set peer ', address, ':', port)

  ok, err = balancer.set_current_peer(address, port)

  if ok then return peer end

  return nil, err or 'balancer could not set the peer'
end

return _M
