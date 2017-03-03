local redis_pool = require 'client-registrations/redis_pool'
local lom = require 'lxp.lom'
local xpath = require 'luaxpath'
local cjson = require 'cjson'

local _M = {}

local initial_access_token = "CHANGE_ME_INITIAL_ACCESS_TOKEN"

-- this will be the prepended to the keys for storing in Redis the registration access token
local access_token_prefix = "access-token#"

 -- save registration access token in Redis
local function update_access_token(response_payload)
  local json_body = cjson.decode(response_payload)
  local client_id = json_body.clientId
  local access_token = json_body.registrationAccessToken
  local redis_key = access_token_prefix..client_id

  local redis, ok = redis_pool.acquire()
  if ok then
    redis:set(redis_key, access_token)
  end
  redis_pool.release(redis)
end

-- get registration access token from Redis
local function get_access_token(client_id)
  local access_token
  local redis_key = access_token_prefix..client_id
  local redis, ok = redis_pool.acquire()
  if ok then
    access_token = redis:get(redis_key)
  end
  redis_pool.release(redis)
  return access_token
end

local function client_registration_request(method, client_details)
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

  local res = ngx.location.capture("/register_client", { 
      method = method,
      body = cjson.encode(body),
      copy_all_vars = true })

  if res.status >= 200 and res.status < 300 then
    update_access_token(res.body)
  end

  return res
end

local function register_client(client_details)
  ngx.var.access_token = initial_access_token
  ngx.var.registration_url = ngx.var.rhsso_endpoint.."/clients-registrations/default" 
  local method = ngx.HTTP_POST
  client_registration_request(method, client_details)
end

local function update_client(client_details)
  local client_id = client_details.client_id
  ngx.var.access_token = get_access_token(client_id)
  ngx.var.registration_url = ngx.var.rhsso_endpoint..'/clients-registrations/default/'..client_id
  local method = ngx.HTTP_PUT
  client_registration_request(method, client_details)
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

return _M