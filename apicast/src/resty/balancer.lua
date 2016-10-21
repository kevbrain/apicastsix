local setmetatable = setmetatable
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local insert = table.insert
local tonumber = tonumber

local balancer = require "ngx.balancer"

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

local function round_robin(peers)
  return peers[1]
end

local modes = {
  ['round-robin'] = round_robin
}

function _M.new(mode)
  local m = modes[mode]

  if not m then
    return nil, 'invalid mode: ' .. tostring(mode)
  end

  return setmetatable({
    mode = m,
    balancer = balancer
  }, mt)
end

function _M.modes()
  local m = {}

  for name, _ in pairs(modes) do
    insert(m,name)
  end

  return m
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

  for _, server in ipairs(servers) do
    local peer = new_peer(server, port)

    if peer and #peer == 2 then
      insert(peers, peer)
    else
      ngx.log(ngx.WARN, 'skipping peer because it misses address or port')
    end
  end

  peers.servers = servers

  return peers
end

function _M.peers(self, servers, port)
  if not servers then
    return nil, 'missing servers'
  end

  local peers, err = convert_servers(servers, port)

  return peers, err
end

function _M.set_peer(self, peers)
  local mode = self.mode
  local balancer = self.balancer

  if not mode then
    return nil, 'not initialized'
  end

  if not balancer then
    return nil, 'balancer not available'
  end

  if not peers then
    return nil, 'missing peers'
  end

  local peer, err = mode(peers)

  if not peer then
    return nil, err or 'no peer found'
  end

  local address, port = unpack(peer)

  if not address or not port then
    return nil, 'peer missing address or port'
  end

  ngx.log(ngx.DEBUG, 'balancer set peer ' .. tostring(address) .. ':' .. tostring(port))

  local ok, err = balancer.set_current_peer(address, port)

  if ok then return peer end

  return nil, err
end

return _M
