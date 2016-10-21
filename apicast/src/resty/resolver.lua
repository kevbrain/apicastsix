local setmetatable = setmetatable
local ipairs = ipairs
local next = next

local resolver_cache = require 'resty.resolver.cache'

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(dns, opts)
  local opts = opts or {}
  local cache = opts.cache or resolver_cache.new()
  return setmetatable({
    dns = dns,
    cache = cache
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
  local m, err = ngx.re.match(address, '^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$', 'o')

  if m then
    return next(m)
  else
    return nil, err
  end
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

  if not dns then
    return nil, 'resolver not initialized'
  end

  if not qname then
    return nil, 'query missing'
  end

  -- TODO: implement cache
  -- TODO: pass proper options to dns resolver (like SRV query type)

  local answers, err = cache:get(qname)

  if not answers then
    ngx.log(ngx.DEBUG, 'resolver query ', qname)

    if is_ip(qname) then
      ngx.log(ngx.DEBUG, 'host is ip address: ', qname)
      answers = { new_answer(qname) }
    else
      answers, err = dns:query(qname)
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

  return servers
end



return _M
