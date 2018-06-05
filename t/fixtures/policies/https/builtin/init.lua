local _M = require('apicast.policy').new('HTTPS', '1.0.0')
local ssl = require('ngx.ssl')
local new = _M.new

function _M.new(configuration)
  local policy = new(configuration)

  if configuration then
    policy.certificate_chain = assert(ssl.parse_pem_cert(configuration.certificate))
    policy.priv_key = assert(ssl.parse_pem_priv_key(configuration.key))
  end

  return policy
end

function _M:ssl_certificate()
  assert(ssl.clear_certs())

  assert(ssl.set_cert(self.certificate_chain))
  assert(ssl.set_priv_key(self.priv_key))
end

return _M
