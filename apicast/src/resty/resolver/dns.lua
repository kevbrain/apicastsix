local resty_resolver = require 'resty.dns.resolver'

local setmetatable = setmetatable
local ipairs = ipairs
local concat = table.concat

local _M = {
  _VERSION = '0.1'
}
local mt = { __index = _M }

function _M.new(_, options)
  local resolvers = {}
  local opts = options or {}
  local nameservers = opts.nameservers or {}

  for _,nameserver in ipairs(nameservers) do
    resolvers[nameserver] = resty_resolver:new({ nameservers = { nameserver }})
  end

  return setmetatable({
    resolvers = resolvers
  }, mt)
end

function _M.query(self, qname, opts)
  local resolvers = self.resolvers
  local answers, err

  for nameserver, resolver in pairs(resolvers) do
    answers, err = resolver:query(qname, opts)

    ngx.log(ngx.DEBUG, 'resolver query: ', qname, ' nameserver: ', concat(nameserver,':'))

    if answers and not answers.errcode and not err then
      break
    end
  end

  return answers, err
end

return _M
