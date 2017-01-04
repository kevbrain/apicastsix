local setmetatable = setmetatable
local tostring = tostring
local rawget = rawget
local next = next
local lower = string.lower
local gsub = string.gsub
local select = select
local type = type

local http_authorization = require 'resty.http_authorization'

local _M = {

}

local mt = {
  __index = _M
}

function _M.new(attributes)
  return setmetatable(attributes or {}, mt)
end

local http_methods_with_body = {
  POST = true,
  PUT = true,
  PATCH = true
}

local function read_body_args(...)
  local method = ngx.req.get_method()

  if not http_methods_with_body[method] then
    return {}, 'not supported'
  end

  ngx.req.read_body()

  local args = ngx.req.get_post_args()
  local results = {}

  for n=1, select('#', ...) do
    results[n] = args[select(n, ...)]
  end

  return results
end

local function read_http_header(name)
  local normalized = gsub(lower(name), '-', '_')
  return ngx.var['http_' .. normalized]
end

local credentials_mt = {
  -- nipairs = only non integer pairs
  __pairs = function (t)
    return function(_, k)
      local v
      repeat
        k, v = next(t, k)
      until k == nil or type(k) ~= 'number'
      return k, v
    end, t, nil
  end
}

local backend_version_credentials = {
  ['1'] = function(credentials)
    local name = (credentials.user_key or 'user_key')
    local user_key

    if credentials.location == 'query' then
      user_key = ngx.var['arg_' .. name] or read_body_args(name)[1]

    elseif credentials.location == 'headers' then
      user_key = read_http_header(name)

    elseif credentials.location == 'authorization' then
      local auth = http_authorization.new(ngx.var.http_authorization)

      user_key = auth.userid or auth.password or auth.token
    else
      return nil, 'invalid credentials location'
    end

    return { user_key, user_key = user_key }
  end,

  ['2'] = function(credentials)
    local app_id_name = (credentials.app_id or 'app_id')
    local app_key_name = (credentials.app_key or 'app_key')

    local app_id, app_key

    if credentials.location == 'query' then
      app_id = ngx.var['arg_' .. app_id_name]
      app_key = ngx.var['arg_' .. app_key_name]

      if not app_id or not app_key then
        local body = read_body_args(app_id_name, app_key_name)

        app_id = app_id or body[1]
        app_key = app_key or body[2]
      end
    elseif credentials.location == 'headers' then
      app_id = read_http_header(app_id_name)
      app_key = read_http_header(app_key_name)

    elseif credentials.location == 'authorization' then
      local auth = http_authorization.new(ngx.var.http_authorization)

      app_id = auth.userid or auth.token
      app_key = auth.password
    else
      return nil, 'invalid credentials location'
    end

    return { app_id, app_key, app_id = app_id, app_key = app_key }
  end,

  ['oauth'] = function(credentials)
    local name = (credentials.access_token or 'access_token')
    local authorization = http_authorization.new(ngx.var.http_authorization)
    local access_token

    if credentials.location == 'query' then
      access_token = ngx.var['arg_' .. name] or read_body_args(name)[1]

    elseif credentials.location == 'headers' then
      access_token = read_http_header(name)

    elseif credentials.location == 'authorization' then
      access_token = authorization.token

    else
      return nil, 'invalid credentials location'
    end

    -- https://tools.ietf.org/html/rfc6750#section-2.1 says:
    -- Resource servers MUST support this method. [Bearer]
    access_token = access_token or authorization.token

    return { access_token, access_token = access_token }
  end
}

function _M.extract_credentials(self)
  local backend_version = tostring(self.backend_version)
  local credentials = rawget(self, 'credentials')

  if not credentials then
    return nil, 'missing credentials'
  end

  local extractor = backend_version_credentials[backend_version]

  if not extractor then
   return nil, 'invalid backend version: ' .. tostring(backend_version)
  end

  local result = extractor(credentials)


  return setmetatable(result, credentials_mt)
end

return _M
