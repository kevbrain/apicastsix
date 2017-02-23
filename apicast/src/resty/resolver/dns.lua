local resty_resolver = require 'resty.dns.resolver'

local setmetatable = setmetatable
local insert = table.insert
local th_spawn = ngx.thread.spawn
local th_wait = ngx.thread.wait
local th_kill = ngx.thread.kill
local unpack = unpack

local _M = {
  _VERSION = '0.1'
}
local mt = { __index = _M }

function _M.new(_, options)
  local resolvers = {}
  local opts = options or {}
  local nameservers = opts.nameservers or {}

  return setmetatable({
    initialized = false,
    resolvers = resolvers,
    nameservers = nameservers
  }, mt)
end

function _M:instance(nameservers)
  local ctx = ngx.ctx
  local resolver = ctx.dns

  if not resolver then
    resolver = self:new({ nameservers = nameservers })
    ctx.dns = resolver
  end

  return resolver
end

function _M:init_resolvers()
  local resolvers = self.resolvers
  local nameservers = self.nameservers

  for i=1,#nameservers do
    insert(resolvers, { nameservers[i], resty_resolver:new({ nameservers = { nameservers[i] }}) })
  end

  self.initialized = true

  return resolvers
end

local function query(resolver, qname, opts, nameserver)
  ngx.log(ngx.DEBUG, 'resolver query: ', qname, ' nameserver: ', nameserver[1],':', nameserver[2] or 53)
  return resolver:query(qname, opts)
end

function _M.query(self, qname, opts)
  local resolvers = self.resolvers

  if not self.initialized then
    resolvers = self:init_resolvers()
  end

  local threads = {}
  local n = #resolvers

  for i=1, n do
    insert(threads, th_spawn(query, resolvers[i][2], qname, opts, resolvers[i][1]))
  end

  local answers, err

  do
    local found, ok
    local i=1
    repeat
      ok, answers, err = th_wait(unpack(threads))
      i = i + 1
      found = ok and answers and not answers.errcode and not err
    until found or i > n
  end

  for i=1, n do
    th_kill(threads[i])
  end

  return answers, err
end

return _M
