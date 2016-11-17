local setmetatable = setmetatable
local ipairs = ipairs
local next = next
local open = io.open
local gmatch = string.gmatch
local match = string.match
local insert = table.insert
local getenv = os.getenv
local concat = table.concat
local io_type = io.type

local semaphore = require "ngx.semaphore"
local resolver_cache = require 'resty.resolver.cache'

local init = semaphore.new(1)

local _M = {
  _VERSION = '0.1',
  _nameservers = {}
}

local mt = { __index = _M }

function _M.parse_nameservers(path)
  local search = {}
  local nameservers = { search = search }
  local path = path or '/etc/resolv.conf'

  local resolver = getenv('RESOLVER')
  if resolver then
    insert(nameservers, { resolver })
    return nameservers
  end

  local handle, err

  if io_type(path) then
    handle = path
  else
    handle, err = open(path)
  end

  local output

  if handle then
    handle:seek("set")
    output = handle:read("*a")
    handle:close()
  else
    ngx.log(ngx.ERR, 'resolver could not get nameservers: ', err)
    return nil, err
  end

  for nameserver in gmatch(output, 'nameserver%s+([^%s]+)') do
    -- TODO: implement port matching based on https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=549190
    local port
    insert(nameservers, { nameserver, port } )
  end

  local domains = match(output, 'search%s+([^\n]+)')
  for domain in gmatch(domains or '', '([^%s]+)') do
    insert(search, domain)
  end

  return nameservers
end

function _M.init_nameservers()
  local nameservers = _M.parse_nameservers() or {}
  for _,nameserver in ipairs(nameservers) do
    ngx.log(ngx.INFO, 'adding ', concat(nameserver,':'), ' as default nameserver')
    insert(_M._nameservers, nameserver)
  end
end

function _M.nameservers()
  local ok, _ = init:wait(0)

  if ok and not next(_M._nameservers) then
    _M.init()
  end

  if ok then
    init:post()
  end

  return _M._nameservers
end

function _M.init()
  _M.init_nameservers()
end

function _M.new(dns, opts)
  local opts = opts or {}
  local cache = opts.cache or resolver_cache.new()
  local search = opts.search or {}

  ngx.log(ngx.DEBUG, 'resolver search domains: ', concat(search, ' '))

  return setmetatable({
    dns = dns,
    cache = cache,
    search = search
  }, mt)
end


local function new_server(answer, port)
  return {
    address = answer.address,
    ttl = answer.ttl,
    port = answer.port or port
  }
end

local function new_answer(address, port)
  return {
    address = address,
    ttl = -1,
    port = port
  }
end

local function is_ip(address)
  local m, err = ngx.re.match(address, '^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$', 'oj')

  if m then
    return next(m)
  else
    return nil, err
  end
end

local function has_tld(qname)
  return match(qname, '%.')
end

local function convert_answers(answers, port)
  local servers = {}

  for _, answer in ipairs(answers) do
    servers[#servers+1] = new_server(answer, port)
  end

  servers.answers = answers

  return servers
end

function _M.get_servers(self, qname, opts)
  local opts = opts or {}
  local dns = self.dns
  local port = opts.port
  local cache = self.cache
  local search = self.search

  if not dns then
    return nil, 'resolver not initialized'
  end

  if not qname then
    return nil, 'query missing'
  end

  -- TODO: implement cache
  -- TODO: pass proper options to dns resolver (like SRV query type)

  local answers, err = cache:get(qname)

  if not answers or #answers.addresses == 0 then
    ngx.log(ngx.DEBUG, 'resolver query: ', qname)

    if is_ip(qname) then
      ngx.log(ngx.DEBUG, 'host is ip address: ', qname)
      answers = { new_answer(qname) }
    else
      answers, err = dns:query(qname, { qtype = dns.TYPE_A })

      if not has_tld(qname) and (not answers or not answers.addresses) then
        for _, domain in ipairs(search) do

          ngx.log(ngx.DEBUG, 'resolver query: ', qname, ' search: ', domain)
          answers, err = dns:query(qname .. '.' .. domain, { qtype = dns.TYPE_A })

          if answers and next(answers.addresses or {}) then break end
        end
      end
    end

    cache:save(answers)
  end

  if err then
    return nil, err
  end

  if not answers then
    return nil, 'no answers'
  end

  local servers = convert_answers(answers, port)

  servers.query = qname

  return servers
end

return _M
