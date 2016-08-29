-- provider_key: <%= provider_key %> --
-- -*- mode: lua; -*-
-- Generated on: <%= Time.now %> --
-- Version:
-- Error Messages per service

local cjson = require 'cjson'
local custom_config = false
local configuration = require 'configuration'
local inspect = require 'inspect'

local _M = {
  configuration = {}
}

function _M.configure(config)
  local contents = configuration.read('spec.json')
  local config = configuration.parse(contents)

  _M.configuration = config
  _M.services = config.services or {}-- for compatibility reasons
end

function _M.init()
  _M.configure({
    services = {
      {
        api_backend = 'https://echo-api.3scale.net',
        backend_version = '1',
        hosts = { 'localhost' },
        backend_authentication_type = 'service_token',
        backend_authentication_value = 'token_value',
        proxy_rules = {
          {
            http_method = "GET",
            pattern = "/get/{value}?param={other}&q=v",
            metric_system_name = "hits",
            delta = 1,
            parameters = {"value" },
            querystring_parameters = {
              param = "{other}",
              q = "v"
            }
          },
          {
            http_method = "POST",
            pattern = "/post/{something}?p={v}&k=b",
            metric_system_name = "hits",
            delta = 1,
            parameters = {"something"},
            querystring_parameters = {
              p = "{v}",
              k = "b"
            }
          },
          {
            http_method = "GET",
            pattern = "/",
            metric_system_name = "hits",
            delta = 1,
            parameters = {},
            querystring_parameters = { }
          }
        }
      }
    }
  })

  math.randomseed(ngx.now())
  -- First calls to math.random after a randomseed tend to be similar; discard them
  for _=1,3 do math.random() end
end

-- Error Codes
local function error_no_credentials(service)
  ngx.log(ngx.INFO, 'no credentials provided for service ' .. tostring(service.id))
  ngx.status = service.auth_missing_status
  ngx.header.content_type = service.auth_missing_headers
  ngx.print(service.error_auth_missing)
  ngx.exit(ngx.HTTP_OK)
end

local function error_authorization_failed(service)
  ngx.log(ngx.INFO, 'authorization failed for service ' .. tostring(service.id))

  ngx.status = service.auth_failed_status
  ngx.header.content_type = service.auth_failed_headers
  ngx.print(service.error_auth_failed)
  ngx.exit(ngx.HTTP_OK)
end

local function error_no_match(service)
  ngx.log(ngx.INFO, 'no rules matched for service ' .. tostring(service.id))
  ngx.status = service.no_match_status
  ngx.header.content_type = service.no_match_headers
  ngx.print(service.error_no_match)
  ngx.exit(ngx.HTTP_OK)
end
-- End Error Codes

-- Aux function to split a string

function string:split(delimiter)
  local result = { }
  local from = 1
  local delim_from, delim_to = string.find( self, delimiter, from )
  if delim_from == nil then return {self} end
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from )
  end
  table.insert( result, string.sub( self, from ) )
  return result
end

local function first_values(a)
  local r = {}
  for k,v in pairs(a) do
    if type(v) == "table" then
      r[k] = v[1]
    else
      r[k] = v
    end
  end
  return r
end

local function build_querystring_formatter(fmt)
  return function (query)
    local function kvmap(f, t)
      local res = {}
      for k, v in pairs(t) do
        table.insert(res, f(k, v))
      end
      return res
    end

    return table.concat(kvmap(function(k,v) return string.format(fmt, k, v) end, query or {}), "&")
  end
end

local build_querystring = build_querystring_formatter("usage[%s]=%s")
local build_query = build_querystring_formatter("%s=%s")


--[[
  Authorization logic
]]--

local function get_auth_params(where, method)
  local params = {}
  if where == "headers" then
    params = ngx.req.get_headers()
  elseif method == "GET" then
    params = ngx.req.get_uri_args()
  else
    ngx.req.read_body()
    params = ngx.req.get_post_args()
  end
  return first_values(params)
end

local function get_debug_value()
  local h = ngx.req.get_headers()
  if h["X-3scale-debug"] == configuration.provider_key then
    return true
  else
    return false
  end
end

function _M.find_service(host)
  for _,service in ipairs(_M.services or {}) do
    for _,_host in ipairs(service.hosts or {}) do
      if _host == host then
        return service
      end
    end
  end
end

local http = {
  get = function(url)
    ngx.log(ngx.INFO, '[http] requesting ' .. url)
    local res = ngx.location.capture(assert(url), { share_all_vars = true })

    ngx.log(ngx.INFO, '[http] status: ' .. tostring(res.status))
    return res
  end
}
local function oauth(params, service)
  ngx.var.cached_key = ngx.var.cached_key .. ":" .. ngx.var.usage
  local access_tokens = ngx.shared.api_keys
  local is_known = access_tokens:get(ngx.var.cached_key)

  if is_known ~= 200 then
    local res = http.get("/threescale_oauth_authrep")

    -- IN HERE YOU DEFINE THE ERROR IF CREDENTIALS ARE PASSED, BUT THEY ARE NOT VALID
    if res.status ~= 200   then
      access_tokens:delete(ngx.var.cached_key)
      ngx.status = res.status
      ngx.header.content_type = "application/json"
      ngx.var.cached_key = nil
      error_authorization_failed(service)
    else
      access_tokens:set(ngx.var.cached_key,200)
    end

    ngx.var.cached_key = nil
  end
end

local function authrep(params, service)
  local cached_key = ngx.var.cached_key .. ":" .. ngx.var.usage
  local api_keys = ngx.shared.api_keys
  local is_known = api_keys:get(cached_key)

  if is_known == 200 then
    ngx.var.cached_key = cached_key
  else
    ngx.log(ngx.INFO, '[cache] key: ' .. cached_key .. ' not known, performing auth')
    local res = http.get("/threescale_authrep")

    if res.status == 200 then
      api_keys:set(cached_key,200)
    else -- TODO: proper error handling
      api_keys:delete(cached_key)
      ngx.status = res.status
      ngx.header.content_type = "application/json"
      -- error_authorization_failed is an early return, so we have to reset cached_key to nil before -%>
      ngx.var.cached_key = nil
      error_authorization_failed(service)
    end
    -- set this request_to_3scale_backend to nil to avoid doing the out of band authrep -%>
    ngx.var.cached_key = nil
  end
end

function _M.authorize(backend_version, params, service)
  if backend_version == 'oauth' then
    oauth(params, service)
  else
    authrep(params, service)
  end
end

function _M.access(host)
  local host = host or ngx.var.host
  local service = _M.find_service(host) or ngx.exit(404)
  local backend_version = service.backend_version
  local params = {}
  local usage = {}
  local matched_patterns = ''

  if ngx.status == 403  then
    ngx.say("Throttling due to too many requests")
    ngx.exit(403)
  end

  local credentials = service.credentials
  local parameters = get_auth_params(credentials.location, string.split(ngx.var.request, " ")[1] )
  ngx.var.secret_token = service.secret_token
  ngx.var.backend_authentication_type = service.backend_authentication.type
  ngx.var.backend_authentication_value = service.backend_authentication.value

  if backend_version == '1' then
    params.user_key = parameters[credentials.user_key]
    ngx.var.cached_key = table.concat({service.id, params.user_key}, ':')

  elseif backend_version == '2' then
    params.app_id = parameters[credentials.app_id]
    params.app_key = parameters[credentials.app_key] -- or ""  -- Uncoment the first part if you want to allow not passing app_key

    ngx.var.cached_key = table.concat({service.id, params.app_id, params.app_key}, ':')

  elseif backend_version == 'oauth' then
    error('oauth unsupported')
    ngx.var.access_token = parameters.access_token
    params.access_token = parameters.access_token
    ngx.var.cached_key = table.concat({service.id, params.access_token}, ':')
  else
    error('unknown backend version: ' .. tostring(backend_version))
  end

  if not service:get_credentials(params) then
    return error_no_credentials(service)
  end

  ngx.var.service_id = tostring(service.id)
  ngx.var.proxy_pass = service.api_backend

  usage, matched_patterns = service:extract_usage(ngx.var.request)

  ngx.var.credentials = build_query(params)
  ngx.var.usage = build_querystring(usage)

  -- WHAT TO DO IF NO USAGE CAN BE DERIVED FROM THE REQUEST.
  if ngx.var.usage == '' then
    ngx.header["X-3scale-matched-rules"] = ''
    return error_no_match(service)
  end

  if get_debug_value() then
    ngx.header["X-3scale-matched-rules"] = matched_patterns
    ngx.header["X-3scale-credentials"]   = ngx.var.credentials
    ngx.header["X-3scale-usage"]         = ngx.var.usage
    ngx.header["X-3scale-hostname"]      = ngx.var.hostname
  end

  _M.authorize(backend_version, params, service)
end


function _M.post_action_content()
  local method, path, headers = ngx.req.get_method(), ngx.var.request_uri, ngx.req.get_headers()

  local req = cjson.encode{method=method, path=path, headers=headers}
  local resp = cjson.encode{ body = ngx.var.resp_body, headers = cjson.decode(ngx.var.resp_headers)}

  local cached_key = ngx.var.cached_key

  if cached_key and cached_key ~= "null" then
    ngx.log(ngx.INFO, '[async] reporting to backend asynchronously')
    local status_code = ngx.var.status
    local res1 = http.get("/threescale_authrep?code=".. status_code .. "&req=" .. ngx.escape_uri(req) .. "&resp=" .. ngx.escape_uri(resp))
    if res1.status ~= 200 then
      local api_keys = ngx.shared.api_keys
      api_keys:delete(cached_key)
    end
  else
    ngx.log(ngx.INFO, '[async] skipping after action, no cached key')
  end

  ngx.exit(ngx.HTTP_OK)
end

if custom_config then
  local ok, c = pcall(function() return require(custom_config) end)
  if ok and type(c) == 'table' and type(c.setup) == 'function' then
    c.setup(_M)
  end
end


return _M

-- END OF SCRIPT
