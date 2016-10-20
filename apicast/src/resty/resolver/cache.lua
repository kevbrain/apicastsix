local lrucache = require "resty.lrucache"

local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local min = math.min
local insert = table.insert

local co_yield = coroutine.yield
local co_create = coroutine.create
local co_resume = coroutine.resume


local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(cache)
  local cache = cache or lrucache.new(1000)

  return setmetatable({
    cache = cache
  }, mt)
end

local function compact_answers(servers)
  local hash = {}
  local compact = {}

  for _, server in ipairs(servers) do
    local name = server.name

    local packed = hash[name]

    if packed then
      insert(packed, server)
      packed.ttl = min(packed.ttl, server.ttl)
    else
      packed = {
        server,
        name = name,
        ttl = server.ttl
      }

      insert(compact, packed)
      hash[name] = packed
    end
  end

  return compact
end

function _M.store(self, answer)
  local cache = self.cache

  if not cache then
    return nil, 'not initialized'
  end

  return cache:set(answer.name, answer, answer.ttl)
end

function _M.save(self, answers)
  local answers = compact_answers(answers or {})

  for _, answer in pairs(answers) do
    local _, err = self:store(answer)

    if err then
      return nil, err
    end
  end

  return answers
end


local function fetch(cache, name, stale)
  local circular_reference = {}

  local function fetch_answers(name, stale)
    if not name then
      return {}, 'missing name'
    end

    if circular_reference[name] then
      error('circular reference detected when querying '.. name)
      return
    else
      circular_reference[name] = true
    end

    local answers, stale_answers = cache:get(name)

    if not answers then
      if stale and stale_answers then
        return stale_answers
      else
        return {}
      end
    end

    return answers
  end

  local function yieldfetch(name, stale)
    local answers = fetch_answers(name, stale)

    for _,answer in ipairs(answers) do
      yieldfetch(answer.cname)
      co_yield(answer)
    end
  end

  local co = co_create(function () yieldfetch(name, stale) end)

  return function ()
    local code, res = co_resume(co)

    if code then
      return res
    else
      return nil, 'error when trying to fetch from cache'
    end
  end
end

function _M.get(self, name)
  local cache = self.cache

  if not cache then
    return nil, 'not initialized'
  end

  local answers = { addresses = {} }

  for data in fetch(cache, name) do
    insert(answers, data)

    if data.address then
      insert(answers.addresses, data.address)
    end
  end

  return answers
end

return _M
