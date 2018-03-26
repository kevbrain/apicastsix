local policy_chain = require('apicast.policy_chain').default()

local rate_limit_policy = require('apicast.policy.rate_limiting_to_service').new({
  limitters = {
  {
    limitter = "resty.limit.conn",
    key = "limit1",
    values = {20, 10, 0.5}
  },
  {
    limitter = "resty.limit.req",
    key = "limit2",
    values = {18, 9}
  },
  {
    limitter = "resty.limit.count",
    key = "limit3",
    values = {10, 10}
  }},
  redis_info = {
    host = '127.0.0.1',
    port = 6379,
    db = 1
  }
})

policy_chain:insert(rate_limit_policy, 1)

return {
  policy_chain = policy_chain
}
