local balancer = require 'resty.balancer'

local _M = {
  _VERSION = '0.1'
}

local random = math.random

function _M.new()
  return balancer.new(_M.call)
end

local function random_peer(peers)
  local n = #peers
  local i = random(1, n)

  return peers[i], i
end

function _M.call(peers)
  return random_peer(peers)
end

return _M
