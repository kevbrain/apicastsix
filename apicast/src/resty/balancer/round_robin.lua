local balancer = require 'resty.balancer'
local random = require 'resty.balancer.random'

local _M = {
  _VERSION = '0.1'
}

local semaphore = require 'ngx.semaphore'
local call = semaphore.new(1)

local cursor = {}

function _M.new()
  return balancer.new(_M.call)
end


function _M.call(peers)
  local hash = peers.hash

  if not hash then
    return random.call(peers)
  end

  local ok, _ = call:wait(0)

  local peer
  local i = cursor[hash] or peers.cur

  if i then
    peer = peers[i]
  else
    peer, i = random.call(peers)
    cursor[hash] = i
  end

  if i == #peers then
    cursor[hash] = 1
  else
    cursor[hash] = i + 1
  end

  if ok then call:post(1) end

  return peer, i
end

return _M
