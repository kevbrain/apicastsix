local _M = {}

local lom = require 'lxp.lom'
local xpath = require 'luaxpath'
local cjson = require 'cjson'
local router = require('router')
local http_ng = require "resty.http_ng"
local ts = require 'threescale_utils'
local env = require 'resty.env'


-- this will be the prepended to the keys for storing in Redis the registration access token
local access_token_prefix = "access-token#"

 -- save registration access token in Redis
local function update_access_token(response_payload)
  local json_body = cjson.decode(response_payload)
  local client_id = json_body.clientId
  local access_token = json_body.registrationAccessToken
  local redis_key = access_token_prefix..client_id

  local redis = ts.connect_redis()

  if redis then
    redis:set(redis_key, access_token)
    ts.release_redis(redis)
  end
end

-- get registration access token from Redis
local function get_access_token(client_id)
  local access_token
  local redis_key = access_token_prefix..client_id
  local redis = ts.connect_redis()

  if redis then
    access_token = redis:get(redis_key)
    ts.release_redis(redis)
  end

  return access_token
end

local function client_registration_request(method, client_details, url, access_token)
  local body = {
    clientId = client_details.client_id,
    secret = client_details.client_secret,
    name = client_details.name,
    description = client_details.description,
    consentRequired = true -- we want the user to give consent
  }

  if client_details.redirect_url then
    body.redirectUris = { client_details.redirect_url }
  end

  local req_body = cjson.encode(body)

  local http_client = http_ng.new()
  local opts = { headers = { ['Content-Type'] = "application/json",
                  ['Accept'] = "application/json",
                  ['Authorization'] = "Bearer "..access_token
       }, ssl = { verify = false }}
  local res

  if method == ngx.HTTP_PUT then
    res = http_client.put(url, req_body, opts)
  else
    res = http_client.post(url, req_body, opts)
  end

  if res.status >= 200 and res.status < 300 then
    update_access_token(res.body)
  end

  return res
end

local function register_client(client_details)
  local access_token = env.get('RHSSO_INITIAL_TOKEN')
  local url = ngx.var.rhsso_endpoint.."/clients-registrations/default"
  local method = ngx.HTTP_POST
  client_registration_request(method, client_details, url, access_token)
end

local function update_client(client_details)
  local client_id = client_details.client_id
  local access_token = get_access_token(client_id)
  local url = ngx.var.rhsso_endpoint..'/clients-registrations/default/'..client_id
  local method = ngx.HTTP_PUT
  client_registration_request(method, client_details, url, access_token)
end

function _M.handle()
  ngx.req.read_body()
  local body = ngx.req.get_body_data()

  if body then
    local root = lom.parse(body)
    local action = xpath.selectNodes(root, '/event/action/text()')[1]
    local t = xpath.selectNodes(root, '/event/type/text()')[1]
    if (t == 'application' and (action == 'updated' or action == 'created')) then

      local client_details = {
        client_id = xpath.selectNodes(root, '/event/object/application/application_id/text()')[1],
        client_secret = xpath.selectNodes(root, '/event/object/application/keys/key/text()')[1],
        redirect_url = xpath.selectNodes(root, '/event/object/application/redirect_url/text()')[1],
        name = xpath.selectNodes(root, '/event/object/application/name/text()')[1],
        description = xpath.selectNodes(root, '/event/object/application/description/text()')[1]
      }

      if action == 'created' then
        register_client(client_details)
      elseif action == 'updated' then
        update_client(client_details)
      end
    end
  end
end

function _M.router()
  local r = router.new()

  r:post('/webhooks', _M.handle)

  return r
end

function _M.call(method, uri, ...)
  local r = _M.router()

  local ok, err = r:execute(method or ngx.req.get_method(),
                                 uri or ngx.var.uri,
                                 unpack(... or {}))

  if not ok then
    ngx.status = 404
  end

  if err then
    ngx.say(err)
  end
end

return _M