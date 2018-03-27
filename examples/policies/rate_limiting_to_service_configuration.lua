local policy_chain = require('apicast.policy_chain').default()

local rate_limit_policy = require('apicast.policy.rate_limiting_to_service').new({
  limiters = {
  {
    name = "connections",
    key = "limit1",
    conn = 20,
    burst = 10,
    delay = 0.5
  },
  {
    name = "leaky_bucket",
    key = "limit2",
    rate = 18,
    burst = 9
  },
  {
    name = "fixed_window",
    key = "limit3",
    count = 10,
    window = 10
  }},
  redis_url = "redis://localhost:6379/1"
})

policy_chain:insert(rate_limit_policy, 1)

return {
  policy_chain = policy_chain
}
