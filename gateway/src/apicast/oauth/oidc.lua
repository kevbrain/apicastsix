local JWT = require 'resty.jwt'
local jwt_validators = require 'resty.jwt-validators'

local lrucache = require 'resty.lrucache'
local util = require 'apicast.util'

local setmetatable = setmetatable
local ngx_now = ngx.now
local format = string.format
local type = type

local _M = {
  cache_size = 10000,
}

function _M.reset()
  _M.cache = lrucache.new(_M.cache_size)
end

_M.reset()

local mt = {
  __index = _M,
  __tostring = function()
    return 'OpenID Connect'
  end
}

local empty = {}

function _M.new(service)
  local oidc = service.oidc or empty

  local issuer = oidc.issuer or ""
  local config = oidc.config or empty
  local alg_values = config.id_token_signing_alg_values_supported or empty

  local err
  if #issuer == 0 or #alg_values == 0 then
    err = 'missing OIDC configuration'
  end

  return setmetatable({
    service = service,
    config = config,
    issuer = issuer,
    keys = oidc.keys or empty,
    clock = ngx_now,
    alg_whitelist = util.to_hash(alg_values),
    -- https://tools.ietf.org/html/rfc7523#section-3
    jwt_claims = {
      -- 1. The JWT MUST contain an "iss" (issuer) claim that contains a
      -- unique identifier for the entity that issued the JWT.
      iss = jwt_validators.equals_any_of({ issuer }),

      -- 2. The JWT MUST contain a "sub" (subject) claim identifying the
      -- principal that is the subject of the JWT.
      sub = jwt_validators.required(),

      -- 3. The JWT MUST contain an "aud" (audience) claim containing a
      -- value that identifies the authorization server as an intended
      -- audience.
      aud = jwt_validators.required(),

      -- 4. The JWT MUST contain an "exp" (expiration time) claim that
      -- limits the time window during which the JWT can be used.
      exp = jwt_validators.is_not_expired(),

      -- 5. The JWT MAY contain an "nbf" (not before) claim that identifies
      -- the time before which the token MUST NOT be accepted for
      -- processing.
      nbf = jwt_validators.opt_is_not_before(),

      -- 6. The JWT MAY contain an "iat" (issued at) claim that identifies
      -- the time at which the JWT was issued.
      iat = jwt_validators.opt_greater_than(0),
    },
  }, mt), err
end

local function timestamp_to_seconds_from_now(expiry, clock)
  local time_now = (clock or ngx_now)()
  local ttl = expiry and (expiry - time_now) or nil
  return ttl
end

local function find_public_key(jwt, keys)
  local jwk = keys and keys[jwt.header.kid]
  if jwk then return jwk.pem end
end

-- Parses the token - in this case we assume it's a JWT token
-- Here we can extract authenticated user's claims or other information returned in the access_token
-- or id_token by RH SSO
local function parse_and_verify_token(self, jwt_token)
  local cache = self.cache

  if not cache then
    return nil, 'not initialized'
  end
  local cache_key = format('%s:%s', self.service.id, jwt_token)

  local jwt_obj = cache:get(cache_key)

  if jwt_obj then
    ngx.log(ngx.DEBUG, 'found JWT in cache for ', cache_key)
    return jwt_obj
  end

  jwt_obj = JWT:load_jwt(jwt_token)

  if not jwt_obj.valid then
    ngx.log(ngx.WARN, jwt_obj.reason)
    return jwt_obj, 'JWT not valid'
  end

  if not self.alg_whitelist[jwt_obj.header.alg] then
    return jwt_obj, '[jwt] invalid alg'
  end
  -- TODO: this should be able to use DER format instead of PEM
  local pubkey = find_public_key(jwt_obj, self.keys)

  -- This is keycloak-specific. Its tokens have a 'typ' and we need to verify
  -- it's Bearer.
  local claims = self.jwt_claims
  if jwt_obj.payload and jwt_obj.payload.typ then
    claims.typ = jwt_validators.equals('Bearer')
  end

  jwt_obj = JWT:verify_jwt_obj(pubkey, jwt_obj, self.jwt_claims)

  if not jwt_obj.verified then
    ngx.log(ngx.DEBUG, "[jwt] failed verification for token, reason: ", jwt_obj.reason)
    return jwt_obj, "JWT not verified"
  end

  ngx.log(ngx.DEBUG, 'adding JWT to cache ', cache_key)
  local ttl = timestamp_to_seconds_from_now(jwt_obj.payload.exp, self.clock)
  cache:set(cache_key, jwt_obj, ttl)

  return jwt_obj
end


function _M:transform_credentials(credentials)
  local jwt_obj, err = parse_and_verify_token(self, credentials.access_token)

  if err then
    if ngx.config.debug then
      ngx.log(ngx.DEBUG, 'JWT object: ', require('inspect')(jwt_obj), ' err: ', err, ' reason: ', jwt_obj.reason)
    end
    return nil, nil, nil, jwt_obj and jwt_obj.reason or err
  end

  local payload = jwt_obj.payload

  local app_id = payload.azp or payload.aud
  local ttl = timestamp_to_seconds_from_now(payload.exp)


  --- http://openid.net/specs/openid-connect-core-1_0.html#CodeIDToken
  -- It MAY also contain identifiers for other audiences.
  -- In the general case, the aud value is an array of case sensitive strings.
  -- In the common special case when there is one audience, the aud value MAY be a single case sensitive string.
  if type(app_id) == 'table' then
    app_id = app_id[1]
  end

  ------
  -- OAuth2 credentials for OIDC
  -- @field app_id Client id
  -- @table credentials_oauth
  return { app_id = app_id }, ttl, payload
end



return _M
