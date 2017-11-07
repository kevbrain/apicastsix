local policy = require('policy')
local Proxy = require('proxy')
local _M = policy.new('Local Policy Chain')

local policy_chain = require('policy_chain')

local new = _M.new

function _M.new(...)
  local self = new(...)
  self.policy_chain = policy_chain.build()
  return self
end

local function build_chain(context)
  local proxy = Proxy.new(context.configuration)

  context.proxy = context.proxy or proxy
  context.policy_chain = policy_chain.build({})
end

-- forward all policy methods to the policy chain
for _, phase in policy.phases() do
  _M[phase] = function(self, ...)
    return self.policy_chain[phase](self.policy_chain, ...)
  end
end

local rewrite = _M.rewrite

function _M:rewrite(context, ...)
  build_chain(context)
  rewrite(self, context, ...)
end

return _M
