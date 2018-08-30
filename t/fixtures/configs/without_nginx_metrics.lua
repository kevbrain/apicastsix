local PolicyChain = require('apicast.policy_chain')

local policies = {
  'apicast.policy.load_configuration',
  'apicast.policy.find_service',
  'apicast.policy.local_chain'
}

local policy_chain = PolicyChain.build(policies)

return {
  policy_chain = policy_chain,
  port = { metrics = 9421 },
}
