-- authorized_callback.lua

-- Once the client has been authorized by the API provider in their
-- login, the provider is supposed to send the client (via redirect)
-- to this endpoint, with the same status code that we sent him at the
-- moment of the first redirect
local random = require 'resty.random'
local ts = require 'threescale_utils'

-- The authorization server should send some data in the callback response to let the
-- API Gateway know which user to associate with the token.
-- We assume that this data will be sent as uri params.
-- This function should be over-ridden depending on authorization server implementation.
local function extract_params()
  local params = {}
  local uri_params = ngx.req.get_uri_args()

  params.user_id = uri_params.user_id or uri_params.username
  params.state = uri_params.state
  -- In case state is no longer valid, authorization server might send this so we know where to redirect with error
  params.redirect_uri = uri_params.redirect_uri or uri_params.redirect_url

  if not params.redirect_uri then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.print('{"error":"missing redirect_uri"}')
    return ngx.exit(ngx.status)
  end

  return params
end

-- Check valid state parameter sent
local function check_state(params)
  local required_params = {'state'}

  if ts.required_params_present(required_params, params) then
    local red = ts.connect_redis()
    local tmp_data = ngx.ctx.service.id .. "#tmp_data:".. params.state
    local ok, err = red:exists(tmp_data)

    if not ok or ok == 0 or err then
      ngx.header.content_type = "application/x-www-form-urlencoded"
      ngx.redirect(params.redirect_uri .. "#error=invalid_request&error_description=invalid_or_expired_state&state="..params.state)
    end

    return true
  else
    ngx.header.content_type = "application/x-www-form-urlencoded"
    ngx.redirect(params.redirect_uri .. "#error=invalid_request&error_description=missing_state")
  end
end

-- Retrieve client data from Redis
local function retrieve_client_data(service_id, params)

  local tmp_data = service_id .. "#tmp_data:".. params.state

  local red = ts.connect_redis()
  local ok, err = red:hgetall(tmp_data)

  if not ok then
    ngx.log(0, "no values for tmp_data hash: ".. ts.dump(err))
    ngx.header.content_type = "application/x-www-form-urlencoded"
    return ngx.redirect(params.redirect_uri .. "#error=invalid_request&error_description=invalid_or_expired_state&state=" .. (params.state or ""))
  end

  -- Restore client data
  local client_data = red:array_to_hash(ok)  -- restoring client data
  -- Delete the tmp_data:
  red:del(tmp_data)

  return client_data
end

-- Generate authorization code from params
local function generate_code(client_data)
  return ts.sha1_digest(tostring(random.bytes(20, true)) .. "#code:" .. tostring(client_data.client_id))
end

local function persist_code(client_data, params, code)
  local red = ts.connect_redis()

  local ok, err = red:hmset("c:".. code, {
    client_id = client_data.client_id,
    client_secret = client_data.secret_id,
    redirect_uri = client_data.redirect_uri,
    access_token = client_data.access_token,
    user_id = params.user_id,
    code = code
  })

  if ok then
    return red:expire("c:".. code, 60 * 10) -- code expires in 10 mins
  else
    return ok, err
  end
end

local function store_code(client_data, params, code)
  local ok, err = persist_code(client_data, params, code)

  if not ok then
    ngx.header.content_type = "application/x-www-form-urlencoded"
    return ngx.redirect(params.redirect_uri .. "?error=server_error&error_description=code_storage_failed&state=" .. (params.state or "")), err
  end

  return ok, err
end

-- Returns the code to the client
local function send_code(client_data, code)
  ngx.header.content_type = "application/x-www-form-urlencoded"
  return ngx.redirect( client_data.redirect_uri .. "?code="..code.."&state=" .. (client_data.state or ""))
end

-- Get Authorization Code
local function get_code(service_id, params)
  local client_data = retrieve_client_data(service_id, params)
  local code = generate_code(client_data)

  local stored = store_code(client_data, params, code)

  if stored then
    send_code(client_data, code)
  end
end

local _M = {
  VERSION = '0.0.1'
}

_M.call = function()
  local params = extract_params()

  local is_valid = check_state(params)

  if is_valid then
    get_code(ngx.ctx.service.id, params)
  end
end

_M.generate_code = generate_code
_M.persist_code = persist_code
_M.retrieve_client_data = retrieve_client_data

return _M
