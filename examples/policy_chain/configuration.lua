local resty_env = require('resty.env')
local policy_chain = require('apicast.policy_chain').default()
local echo_policy = require('apicast.policy.echo').new({
  status = tonumber(resty_env.value('ECHO_STATUS') or 201),
  exit = 'request'
})

-- add Echo policy to the chain on the 1st place
policy_chain:insert(echo_policy, 1)

return {
  policy_chain = policy_chain
}
