local policy_chain = require('apicast.policy_chain').default()

local rate_limit_policy = require('apicast.policy.rate_limiting_to_service').new({
  limit = 10,
  period = 10,
  service_name = "rate_limit_service"
})

policy_chain:insert(rate_limit_policy, 1)

return {
        policy_chain = policy_chain
}
