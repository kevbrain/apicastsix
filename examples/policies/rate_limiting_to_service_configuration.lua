local policy_chain = require('apicast.policy_chain').default()

local rate_limit_policy = require('apicast.policy.rate_limiting_to_service').new({
  limiters = {
  {
    limiter = "resty.limit.conn",
    key = "limit1",
    values = {20, 10, 0.5}
  },
  {
    limiter = "resty.limit.req",
    key = "limit2",
    values = {18, 9}
  },
  {
    limiter = "resty.limit.count",
    key = "limit3",
    values = {10, 10}
  }},
  redis_url = "redis://localhost:6379/1"
})

policy_chain:insert(rate_limit_policy, 1)

return {
  policy_chain = policy_chain
}
