local resty_resolver = require 'resty.dns.resolver'

local setmetatable = setmetatable
local pairs = pairs

local _M = {
  _VERSION = '0.1'
}
local mt = { __index = _M }

function _M.new(_, options)
  local resolvers = {}
  local opts = options or {}
  local nameservers = opts.nameservers or {}

  return setmetatable({
    resolvers = resolvers,
    nameservers = nameservers
  }, mt)
end

function _M:init_resolvers()
  local resolvers = self.resolvers
  local nameservers = self.nameservers

  for i=1,#nameservers do
    resolvers[nameservers[i]] = resty_resolver:new({ nameservers = { nameservers[i] }})
  end
  return resolvers
end

function _M.query(self, qname, opts)
  local resolvers = self.resolvers
  local answers, err

  if #resolvers == 0 then
    resolvers = self:init_resolvers()
  end

  for nameserver, resolver in pairs(resolvers) do
    answers, err = resolver:query(qname, opts)

    ngx.log(ngx.DEBUG, 'resolver query: ', qname, ' nameserver: ', nameserver[1],':', nameserver[2])

    if answers and not answers.errcode and not err then
      break
    end
  end

  return answers, err
end

return _M
