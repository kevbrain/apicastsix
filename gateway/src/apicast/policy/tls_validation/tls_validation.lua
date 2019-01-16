-- This is a tls_validation description.

local policy = require('apicast.policy')
local _M = policy.new('tls_validation')
local X509_STORE = require('resty.openssl.x509.store')
local X509 = require('resty.openssl.x509')

local ipairs = ipairs
local tostring = tostring

local debug = ngx.config.debug

local function init_trusted_store(store, certificates)
  for _,certificate in ipairs(certificates) do
    local cert, err = X509.parse_pem_cert(certificate.pem_certificate) -- TODO: handle errors

    if cert then
      store:add_cert(cert)

      if debug then
        ngx.log(ngx.DEBUG, 'adding certificate to the tls validation ', tostring(cert:subject_name()), ' SHA1: ', cert:hexdigest('SHA1'))
      end
    else
      ngx.log(ngx.WARN, 'error whitelisting certificate, err: ', err)

      if debug then
        ngx.log(ngx.DEBUG, 'certificate: ', certificate.pem_certificate)
      end
    end
  end

  return store
end

local new = _M.new
--- Initialize a tls_validation
-- @tparam[opt] table config Policy configuration.
function _M.new(config)
  local self = new(config)
  local store = X509_STORE.new()

  self.x509_store = init_trusted_store(store, config and config.whitelist or {})
  self.error_status = config and config.error_status or 400

  return self
end

function _M:access()
  local cert = X509.parse_pem_cert(ngx.var.ssl_client_raw_cert)
  local store = self.x509_store

  local ok, err = store:validate_cert(cert)

  if not ok then
    ngx.status = self.error_status
    ngx.say(err)
    return ngx.exit(ngx.status)
  end

  return ok, err
end

return _M
