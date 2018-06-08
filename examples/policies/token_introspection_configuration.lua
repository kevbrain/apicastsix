local policy_chain = require('apicast.policy_chain').default()

local token_policy = require('apicast.policy.token_introspection').new({
        auth_type = "client_id+client_secret",
        introspection_url = "http://localhost:8080/auth/realms/3scale/protocol/openid-connect/token/introspect",
        client_id = "YOUR_CLIENT_ID",
        client_secret = "YOUR_CLIENT_SECRET"
})

policy_chain:insert(token_policy)

return {
        policy_chain = policy_chain
}

