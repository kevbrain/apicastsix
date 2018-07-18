local policy = require('apicast.policy')
local policy_phases = require('apicast.policy').phases
local PolicyChain = require('apicast.policy_chain')
local Engine = require('apicast.policy.conditional.engine')

local _M = policy.new('Conditional policy')

local new = _M.new

local function build_policy_chain(chain)
  if not chain then return {} end

  local policies = {}

  for i=1, #chain do
    policies[i] = PolicyChain.load_policy(
      chain[i].name,
      chain[i].version,
      chain[i].configuration
    )
  end

  return PolicyChain.new(policies)
end

function _M.new(config)
  local self = new(config)
  self.condition = config.condition or true
  self.policy_chain = build_policy_chain(config.policy_chain)
  return self
end

local function condition_is_true(condition)
  return Engine.evaluate(condition)
end

function _M:export()
  return self.policy_chain:export()
end

-- Forward policy phases to chain
for _, phase in policy_phases() do
  _M[phase] = function(self, context)
    if condition_is_true(self.condition) then
      ngx.log(ngx.DEBUG, 'Condition met in conditional policy')
      self.policy_chain[phase](self.policy_chain, context)
    else
      ngx.log(ngx.DEBUG, 'Condition not met in conditional policy')
    end
  end
end

-- To avoid calling init and init_worker more than once in the policies
_M.init = function() end
_M.init_worker = function() end

return _M
