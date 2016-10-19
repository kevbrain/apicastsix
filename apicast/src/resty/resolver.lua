local setmetatable = setmetatable
local ipairs = ipairs

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(dns)
  return setmetatable({
    dns = dns
  }, mt)
end


local function new_server(answer, port)
  return {
    address = answer.address,
    ttl = answer.ttl,
    port = answer.port or port
  }
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

  if not dns then
    return nil, 'resolver not initialized'
  end

  -- TODO: implement cache
  -- TODO: pass proper options to dns resolver (like SRV query type)

  local answers, err = dns:query(qname)

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
