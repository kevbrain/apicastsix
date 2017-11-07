local policy = require('policy')
local Proxy = require('proxy')
local _M = policy.new('Local Policy Chain')

local default_chain = require('policy_chain').build()

local function find_policy_chain(context)
  return context.policy_chain or (context.service and context.service.policy_chain) or default_chain
end

local function build_chain(context)
  local proxy = Proxy.new(context.configuration)

  context.proxy = context.proxy or proxy
  context.policy_chain = find_policy_chain(context)
end

-- forward all policy methods to the policy chain
for _, phase in policy:phases() do
  _M[phase] = function(_, context, ...)
    local policy_chain = find_policy_chain(context)

    if policy_chain then
      return policy_chain[phase](policy_chain, context, ...)
    end
  end
end

local rewrite = _M.rewrite

function _M:rewrite(context, ...)
  build_chain(context)
  rewrite(self, context, ...)
end

return _M
