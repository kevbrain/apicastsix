local _M = {
  _VERSION = '0.01',
}

local inspect = require 'inspect'
local mt = { __index = _M }

local function map(func, tbl)
  local newtbl = {}
  for i,v in pairs(tbl) do
    newtbl[i] = func(v)
  end
  return newtbl
end

local function set_or_inc(t, name, delta)
  return (t[name] or 0) + (delta or 0)
end

local function regexpify(path)
  return path:gsub('?.*', ''):gsub("{.-}", '([\\w_.-]+)'):gsub("%.", "\\.")
end

local function check_rule(req, rule, usage_t, matched_rules)
  local param = {}
  local p = regexpify(rule.pattern)
  local m = ngx.re.match(req.path, string.format("^%s",p))

  if m and req.method == rule.method then
    local args = req.args
    if rule.querystring_params(args) then -- may return an empty table
    -- when no querystringparams
    -- in the rule. it's fine
    for i,p in ipairs(rule.parameters or {}) do
      param[p] = m[i]
    end

    table.insert(matched_rules, rule.pattern)
    usage_t[rule.system_name] = set_or_inc(usage_t, rule.system_name, rule.delta)
    end
  end
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

local function get_auth_params(method)
  local params = {}
  if method == "GET" then
    params = ngx.req.get_uri_args()
  else
    ngx.req.read_body()
    params = ngx.req.get_post_args()
  end
  return first_values(params)
end

local function check_querystring_params(params, args)
  for k,v in pairs(params) do
    -- TODO: rewrite the function from ruby
  end

  return true
end

function _M.parse_service(service)
  local backend_version = service.backend_version
  local proxy = service.proxy or {}
  local backend = proxy.backend or {}

  return {
      id = service.id or 'default',
      backend_version = tostring(service.backend_version),
      hosts = proxy.hosts or { 'localhost' }, -- TODO: verify localhost is good default
      api_backend = proxy.api_backend,
      error_auth_failed = proxy.error_auth_failed,
      error_auth_missing = proxy.error_auth_missing,
      auth_failed_headers = proxy.error_headers_auth_failed,
      auth_missing_headers = proxy.error_headers_auth_missing,
      error_no_match = proxy.error_no_match,
      no_match_headers = proxy.error_headers_no_match,
      no_match_status = proxy.error_status_no_match or 404,
      auth_failed_status = proxy.error_status_auth_failed or 403,
      auth_missing_status = proxy.error_status_auth_missing or 401,
      secret_token = proxy.secret_token,
      hostname_rewrite = type(proxy.hostname_rewrite) == 'string' and proxy.hostname_rewrite,
      backend_authentication = {
        type = service.backend_authentication_type,
        value = service.backend_authentication_value
      },
      backend = {
        endpoint = backend.endpoint,
        host = backend.host
      },
      credentials = {
        location = proxy.credentials_location or 'query',
        user_key = string.lower(proxy.auth_user_key or 'user_key'),
        app_id = string.lower(proxy.auth_app_id or 'app_id'),
        app_key = string.lower(proxy.auth_app_key or 'app_key') -- TODO: use App-Key if location is headers
      },
      get_credentials = function(service, params)
        local credentials
        if service.backend_version == '1' then
          credentials = params.user_key
        elseif service.backend_version == '2' then
          credentials = (params.app_id and params.app_key)
        elseif service.backend_version == 'oauth' then
          credentials = (params.access_token or params.authorization)
        else
          error("Unknown backend version: " .. tostring(backend_version))
        end
        return credentials
      end,
      extract_usage = function (service, request, args)
        local method, url = unpack(string.split(request," "))
        local path, querystring = unpack(string.split(url, "?"))
        local usage_t =  {}
        local matched_rules = {}

        local args = get_auth_params(method)

        ngx.log(ngx.DEBUG, '[mapping] service ' .. service.id .. ' has ' .. #service.rules .. ' rules')

        for i,r in ipairs(service.rules) do
          check_rule({path=path, method=method, args=args}, r, usage_t, matched_rules)
        end

        -- if there was no match, usage is set to nil and it will respond a 404, this behavior can be changed
        return usage_t, table.concat(matched_rules, ", ")
      end,
      rules = map(function(proxy_rule)
        return {
          method = proxy_rule.http_method,
          pattern = proxy_rule.pattern,
          parameters = proxy_rule.parameters,
          querystring_params = function(args)
            return check_querystring_params(proxy_rule.querystring_parameters or {}, args)
          end,
          system_name = proxy_rule.metric_system_name or error('missing metric name of rule ' .. inspect(proxy_rule)),
          delta = proxy_rule.delta
        }
      end, proxy.proxy_rules or {})
    }
end

function _M.parse(contents, encoder)
  if not contents then return _M.new() end
  if type(contents) == 'table' then return _M.new(contents) end

  encoder = encoder or require 'cjson'
  local config = encoder.decode(contents)

  return _M.new(config)
end

function _M.read(path)
  ngx.log(ngx.INFO, 'configuration loading file ' .. path)
  return assert(io.open(path)):read('*a')
end

function _M.new(configuration)
  configuration = configuration or {}
  local services = (configuration or {}).services or {}

  return setmetatable({
    version = configuration.timestamp,
    services = map(_M.parse_service, services),
    debug_header = configuration.provider_key -- TODO: change this to something secure
  }, mt)
end

function _M.boot()
  local endpoint = os.getenv('THREESCALE_PORTAL_ENDPOINT')
  local file = os.getenv('THREESCALE_CONFIG_FILE')

  return _M.load() or (file and _M.read(file)) or _M.download(endpoint)
end

function _M.save(config)
  _M.config = config -- TODO: use shmem
end

function _M.load()
  return _M.config
end

function _M.download(endpoint)
  if not endpoint then
    return nil, 'missing endpoint'
  end

  local http = require "resty.http"


  local httpc = http.new()

  httpc:set_timeout(10000)
  local match = ngx.re.match(endpoint, "^(https?):\\/\\/(?:(.+)@)?([^\\/\\s]+)(\\/.+)?$")

  if not match then
    return nil, 'invalid endpoint' -- TODO: maybe improve the error message?
  end

  local scheme, userinfo, host, path = unpack(match)

  if path == '/' then path = nil end

  local url = table.concat({ scheme, '://', host, path or '/admin/api/nginx/spec.json' }, '')

  local match = ngx.re.match(tostring(userinfo), "^([^:\\s]+)?(?::(.*))?$")
  local user, pass = unpack(match)

  local headers = {}

  if user or pass then
    headers['Authorization'] = "Basic " .. ngx.encode_base64(table.concat({ user or '', pass or '' }, ':'))
  end

  -- TODO: this does not fully implement HTTP spec, it first should send
  -- request without Authentication and then send it after gettting 401

  local res, err = httpc:request_uri(url, {
    method = "GET",
    headers = headers
  })

  if res then
    return res.body or res:read_body()
  else
    return nil, err
  end
end

return _M
