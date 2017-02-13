local max = math.max
local min = math.min
local random = math.random

local balancer = require 'resty.balancer'
local semaphore = require 'ngx.semaphore'
local balancer_random = require 'resty.balancer.random'

local _M = {
  _VERSION = '0.1'
}

local call = semaphore.new(1)

local cursor = {}

function _M.new()
  return balancer.new(_M.call)
end

function _M.reset()
  cursor = {}
end

function _M.call(peers)
  if #peers == 0 then
    return nil, 'empty peers'
  end

  local hash = peers.hash

  if not hash then
    return balancer_random.call(peers)
  end

  local ok, _ = call:wait(0)

  local n = #peers
  local i = min(max(cursor[hash] or peers.cur or random(1, n), 0), n)
  local peer = peers[i]

  cursor[hash] = (i % n) + 1

  if ok then call:post(1) end

  return peer, i
end

return _M
