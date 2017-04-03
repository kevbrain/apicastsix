local max = math.max
local min = math.min
local random = math.random

local balancer = require 'resty.balancer'
local balancer_random = require 'resty.balancer.random'
local lrucache = require 'resty.lrucache'

local _M = {
  _VERSION = '0.1',
  cache_size = 1000
}

local cursor

function _M.new()
  return balancer.new(_M.call)
end

function _M.reset()
  cursor = lrucache.new(_M.cache_size)
end

_M.reset()

function _M.call(peers)
  if #peers == 0 then
    return nil, 'empty peers'
  end

  local hash = peers.hash

  if not hash then
    return balancer_random.call(peers)
  end

  -- This looks like there might be a race condition but I think it is not.
  -- The VM will not schedule another thread until there is IO and in this case there is no IO.
  -- So this block stays the only one being executed and no one can access the same cursor value.
  local n = #peers
  local i = min(max(cursor:get(hash) or peers.cur or random(1, n), 0), n)
  local peer = peers[i]

  cursor:set(hash, (i % n) + 1)

  return peer, i
end

return _M
