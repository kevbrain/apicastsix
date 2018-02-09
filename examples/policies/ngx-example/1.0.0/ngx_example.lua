local _M = require('apicast.policy').new('Nginx Example', '1.0.0')

local new = _M.new

local ipairs = ipairs
local insert = table.insert

function _M.new(configuration)
  local self = new()

  local ops = {}

  local config = configuration or {}
  local set_header = config.set_header or {}

  for _, header in ipairs(set_header) do
    insert(ops, function()
      ngx.log(ngx.NOTICE, 'setting header: ', header.name, ' to: ', header.value)
      ngx.req.set_header(header.name, header.value)
    end)
  end

  self.ops = ops

  return self
end

function _M:rewrite()
  for _,op in ipairs(self.ops) do
    op()
  end
end

return _M
