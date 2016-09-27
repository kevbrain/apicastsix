local _M = {
  _VERSION = '0.01',
}

local str_len = string.len

local inspect = require 'inspect'
local cjson = require 'cjson'
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

local regex_variable = '\\{[-\\w_]+\\}'

local function check_querystring_params(params, args)
  for param, expected in pairs(params) do
    local m, err = ngx.re.match(expected, regex_variable)
    local value = args[param]

    if m then
      if not value then -- regex variable have to have some value
        ngx.log(ngx.DEBUG, 'check query params ' .. param .. ' value missing ' .. tostring(expected))
        return false
      end
    else
      if err then ngx.log(ngx.ERR, 'check match error ' .. err) end

      if value ~= expected then -- normal variables have to have exact value
        ngx.log(ngx.DEBUG, 'check query params does not match ' .. param .. ' value ' .. tostring(value) .. ' == ' .. tostring(expected))
        return false
      end
    end
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
      oauth_login_url = type(proxy.oauth_login_url) == 'string' and str_len(proxy.oauth_login_url) > 0 and proxy.oauth_login_url or nil,
      secret_token = proxy.secret_token,
      hostname_rewrite = type(proxy.hostname_rewrite) == 'string' and str_len(proxy.hostname_rewrite) > 0 and proxy.hostname_rewrite,
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

function _M.decode(contents, encoder)
  if not contents then return nil end
  if type(contents) == 'string' and str_len(contents) == 0 then return nil end
  if type(contents) == 'table' then return contents end

  encoder = encoder or cjson

  local config = encoder.decode(contents)

  if config == encoder.null then
    return nil
  end

  return config
end

function _M.parse(contents, encoder)
  local config = _M.decode(contents, encoder)

  return _M.new(config)
end

function _M.read(path)
  if not path or str_len(tostring(path)) == 0 then
    return nil, 'missing path'
  end
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

  return _M.load() or _M.read(file) or _M.download(endpoint) or _M.curl(endpoint) or error('missing configuration')
end

function _M.save(config)
  _M.config = config -- TODO: use shmem
end

function _M.load()
  return _M.config
end

local util = require 'util'

function _M.init()
  local config, exit, code = util.system("cd '" .. ngx.config.prefix() .."' && libexec/boot")

  if config then
    if str_len(config) > 0 then return config end
  elseif exit then
    if code then
      ngx.log(ngx.ERR, 'boot could not get configuration, ' .. tostring(exit) .. ': '.. tostring(code))
    else
      ngx.log(ngx.ERR, 'boot failed read: '.. tostring(exit))
    end
  end
end

function _M.download(endpoint)
  local url, err = _M.url(endpoint)

  if not url and err then
    return nil, err
  end

  local scheme, user, pass, host, port, path = unpack(url)
  if port then host = table.concat({host, port}, ':') end

  local url = table.concat({ scheme, '://', host, path or '/admin/api/nginx/spec.json' }, '')

  local http = require "resty.http"
  local httpc = http.new()
  local headers = {}

  httpc:set_timeout(10000)

  if user or pass then
    headers['Authorization'] = "Basic " .. ngx.encode_base64(table.concat({ user or '', pass or '' }, ':'))
  end

  -- TODO: this does not fully implement HTTP spec, it first should send
  -- request without Authentication and then send it after gettting 401

  ngx.log(ngx.INFO, 'configuration request sent: ' .. url)

  local res, err = httpc:request_uri(url, {
    method = "GET",
    headers = headers,
    ssl_verify = false
  })

  if err then
    ngx.log(ngx.WARN, 'configuration download error: ' .. err)
  end

  local body = res and (res.body or res:read_body())

  if body then
    ngx.log(ngx.DEBUG, 'configuration response received:' .. body)
    return body
  else
    return nil, err
  end
end

function _M.url(endpoint)
  if not endpoint then
    return nil, 'missing endpoint'
  end

  local match = ngx.re.match(endpoint, "^(https?):\\/\\/(?:(.+)@)?([^\\/\\s]+?)(?::(\\d+))?(\\/.+)?$")

  if not match then
    return nil, 'invalid endpoint' -- TODO: maybe improve the error message?
  end

  local scheme, userinfo, host, port, path = unpack(match)

  if path == '/' then path = nil end

  local match = userinfo and ngx.re.match(tostring(userinfo), "^([^:\\s]+)?(?::(.*))?$")
  local user, pass = unpack(match or {})

  return { scheme, user or false, pass or false, host, port or false, path or nil }
end


function _M.curl(endpoint)
  local url, err = _M.url(endpoint)

  if not url and err then
    return nil, err
  end

  local scheme, user, pass, host, port, path = unpack(url)

  if port then host = table.concat({host, port}, ':') end

  local url = table.concat({ scheme, '://', table.concat({user or '', pass or ''}, ':'), '@', host, path or '/admin/api/nginx/spec.json' }, '')

  local config, exit, code = util.system('curl --silent --show-error --fail --max-time 3 ' .. url)

  ngx.log(ngx.INFO, 'configuration request sent: ' .. url)

  if config then
    ngx.log(ngx.DEBUG, 'configuration response received:' .. config)
    return config
  else
    if code then
      ngx.log(ngx.ERR, 'configuration download error ' .. exit .. ' ' .. code)
      return nil, 'curl fished with ' .. exit .. ' ' .. code
    else
      ngx.log(ngx.WARN, 'configuration download error: ' .. exit)
      return nil, exit
    end
  end
end

return _M
