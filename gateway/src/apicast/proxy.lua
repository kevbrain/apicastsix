------------
-- Proxy
-- Module that handles the request authentication and proxying upstream.
--
-- @module proxy
-- @author mikz
-- @license Apache License Version 2.0

local env = require 'resty.env'
local custom_config = env.get('APICAST_CUSTOM_CONFIG')
local util = require('apicast.util')
local resty_lrucache = require('resty.lrucache')
local backend_cache_handler = require('apicast.backend.cache_handler')
local Usage = require('apicast.usage')
local errors = require('apicast.errors')

local resty_url = require 'resty.url'

local assert = assert
local type = type
local insert = table.insert
local concat = table.concat
local gsub = string.gsub
local tonumber = tonumber
local setmetatable = setmetatable
local ipairs = ipairs
local encode_args = ngx.encode_args
local resty_resolver = require 'resty.resolver'
local semaphore = require('ngx.semaphore')
local backend_client = require('apicast.backend_client')
local http_ng_ngx = require('resty.http_ng.backend.ngx')
local timers = semaphore.new(tonumber(env.get('APICAST_REPORTING_THREADS') or 0))

local empty = {}

local response_codes = env.enabled('APICAST_RESPONSE_CODES')

local using_post_action = response_codes or timers:count() < 1

if not using_post_action then
  ngx.log(ngx.WARN, 'using experimental asynchronous reporting threads: ', timers:count())
end

local _M = { }

local mt = {
  __index = _M
}

function _M.shared_cache()
  return ngx.shared.api_keys or resty_lrucache.new(1)
end

function _M.new(configuration)
  local cache = _M.shared_cache() or error('missing cache store')

  if not cache then
    ngx.log(ngx.WARN, 'apicast cache error missing shared memory zone api_keys')
  end

  local cache_handler = backend_cache_handler.new(env.get('APICAST_BACKEND_CACHE_HANDLER'))

  return setmetatable({
    configuration = assert(configuration, 'missing proxy configuration'),
    cache = cache,
    cache_handler = cache_handler,
  }, mt)
end

local function debug_header_enabled(service)
  local debug_header_value = ngx.var.http_x_3scale_debug
  return debug_header_value and debug_header_value == service.backend_authentication.value
end

local function output_debug_headers(service, usage, credentials)
  ngx.log(ngx.INFO, 'usage: ', usage, ' credentials: ', credentials)

  if debug_header_enabled(service) then
    ngx.header["X-3scale-matched-rules"] = ngx.ctx.matched_patterns
    ngx.header["X-3scale-credentials"]   = credentials
    ngx.header["X-3scale-usage"]         = usage
    ngx.header["X-3scale-hostname"]      = ngx.var.hostname
  end
end

-- Converts a usage to the format expected by the 3scale backend client.
local function format_usage(usage)
  local res = {}

  local usage_metrics = usage.metrics
  local usage_deltas = usage.deltas

  for _, metric in ipairs(usage_metrics) do
    local delta = usage_deltas[metric]
    res['usage[' .. metric .. ']'] = delta
  end

  return res
end

local function matched_patterns(matched_rules)
  local patterns = {}

  for _, rule in ipairs(matched_rules) do
    insert(patterns, rule.pattern)
  end

  return patterns
end

function _M:authorize(service, usage, credentials, ttl)
  if not usage or not credentials then return nil, 'missing usage or credentials' end

  local formatted_usage = format_usage(usage)

  local encoded_usage = encode_args(formatted_usage)
  if encoded_usage == '' then
    return errors.no_match(service)
  end
  local encoded_credentials = encode_args(credentials)

  output_debug_headers(service, encoded_usage, encoded_credentials)

  -- NYI: return to lower frame
  local cached_key = ngx.var.cached_key .. ":" .. encoded_usage
  local cache = self.cache
  local is_known = cache:get(cached_key)

  if is_known == 200 then
    ngx.log(ngx.DEBUG, 'apicast cache hit key: ', cached_key)
    ngx.var.cached_key = cached_key
  else
    ngx.log(ngx.INFO, 'apicast cache miss key: ', cached_key, ' value: ', is_known)

    -- set cached_key to nil to avoid doing the authrep in post_action
    ngx.var.cached_key = nil

    local backend = assert(backend_client:new(service, http_ng_ngx), 'missing backend')
    local res = backend:authrep(formatted_usage, credentials)

    local authorized, rejection_reason = self:handle_backend_response(cached_key, res, ttl)
    if not authorized then
      if rejection_reason == 'limits_exceeded' then
        return errors.limits_exceeded(service)
      else -- Generic error for now. Maybe return different ones in the future.
        return errors.authorization_failed(service)
      end
    end
  end

  if not using_post_action then
    self:post_action(true)
  end
end

function _M.set_service(service)
  if not service then
    return errors.service_not_found()
  end

  ngx.ctx.service = service
  ngx.var.service_id = service.id

  return service
end

function _M.get_upstream(service)
  service = service or ngx.ctx.service

  if not service then
    return errors.service_not_found()
  end

  local url = resty_url.split(service.api_backend) or empty
  local scheme = url[1] or 'http'
  local host, port, path =
    url[4], url[5] or resty_url.default_port(url[1]), url[6] or ''

  return {
    server = host,
    host = service.hostname_rewrite or host,
    uri  = scheme .. '://upstream' .. path,
    port = tonumber(port)
  }
end

function _M.set_upstream(service)
  local upstream = _M.get_upstream(service)

  ngx.ctx.upstream = resty_resolver:instance():get_servers(upstream.server, { port = upstream.port })

  ngx.var.proxy_pass = upstream.uri
  ngx.req.set_header('Host', upstream.host or ngx.var.host)
end

local function handle_oauth(service)
  local oauth = service:oauth()

  if oauth then
    ngx.log(ngx.DEBUG, 'using OAuth: ', oauth)
  end

  if oauth and oauth.call then
    local f, params = oauth:call(service)

    if f then
      ngx.log(ngx.DEBUG, 'OAuth matched route')
      return f(params) -- not really about the return value but showing something will call ngx.exit
    end
  end

  return oauth
end

function _M:rewrite(service, context)
  service = _M.set_service(service or ngx.ctx.service)

  -- handle_oauth can terminate the request
  self.oauth = handle_oauth(service)

  ngx.var.secret_token = service.secret_token

  local credentials, err = service:extract_credentials()

  if not credentials then
    ngx.log(ngx.WARN, "cannot get credentials: ", err or 'unknown error')
    return errors.no_credentials(service)
  end

  local usage, matched_rules = service:get_usage(ngx.req.get_method(), ngx.var.uri)
  local cached_key = { service.id }

  -- remove integer keys for serialization
  -- as ngx.encode_args can't serialize integer keys
  -- and verify all the keys exist
  for i=1,#credentials do
    local val = credentials[i]
    if not val then
      return errors.no_credentials(service)
    else
      credentials[i] = nil
    end

    insert(cached_key, val)
  end

  local ctx = ngx.ctx
  local var = ngx.var

  -- save those tables in context so they can be used in the backend client
  context.usage = context.usage or Usage.new()
  context.usage:merge(usage)

  ctx.usage = context.usage
  ctx.credentials = credentials

  self.credentials = credentials
  self.usage = context.usage

  var.cached_key = concat(cached_key, ':')

  if debug_header_enabled(service) then
    local patterns = matched_patterns(matched_rules)
    ctx.matched_patterns = concat(patterns, ', ')
  end

  local ttl

  if self.oauth then
    credentials, ttl, err = self.oauth:transform_credentials(credentials)

    if err then
      ngx.log(ngx.DEBUG, 'oauth failed with ', err)
      return errors.authorization_failed(service)
    end
    ctx.credentials = credentials
    ctx.ttl = ttl
  end

  context.credentials = ctx.credentials
end

function _M:access(service, usage, credentials, ttl)
  local ctx = ngx.ctx

  return self:authorize(service, usage or ctx.usage, credentials or ctx.credentials, ttl or ctx.ttl)
end

local function response_codes_data()
  local params = {}

  if not response_codes then
    return params
  end

  if response_codes then
    params["log[code]"] = ngx.var.status
  end

  return params
end

local function post_action(_, self, cached_key, backend, ...)
  local res = util.timer('backend post_action', backend.authrep, backend, ...)

  if not using_post_action then
    timers:post(1)
  end

  self:handle_backend_response(cached_key, res)
end

local function capture_post_action(self, cached_key, service)
  local backend = assert(backend_client:new(service, http_ng_ngx), 'missing backend')
  local formatted_usage = format_usage(self.usage)
  local res = backend:authrep(formatted_usage, self.credentials, response_codes_data())

  self:handle_backend_response(cached_key, res)
end

local function timer_post_action(self, cached_key, service)
  local backend = assert(backend_client:new(service), 'missing backend')

  local ok, err = timers:wait(10)

  if ok then
    -- TODO: try to do this in different phase and use semaphore to limit number of background threads
    -- TODO: Also it is possible to use sets in shared memory to enqueue work
    local formatted_usage = format_usage(self.usage)
    ngx.timer.at(0, post_action, self, cached_key, backend, formatted_usage, self.credentials, response_codes_data())
  else
    ngx.log(ngx.ERR, 'failed to acquire timer: ', err)
    return capture_post_action(self, cached_key, service)
  end
end

function _M:post_action(force)
  if not using_post_action and not force then
    return nil, 'post action not needed'
  end

  local cached_key = ngx.var.cached_key

  if cached_key and cached_key ~= "null" and cached_key ~= '' then
    ngx.log(ngx.INFO, '[async] reporting to backend asynchronously, cached_key: ', cached_key)

    local service_id = ngx.var.service_id
    local service = ngx.ctx.service or self.configuration:find_by_id(service_id)

    if using_post_action then
      capture_post_action(self, cached_key, service)
    else
      timer_post_action(self, cached_key, service)
    end
  else
    ngx.log(ngx.INFO, '[async] skipping after action, no cached key')
  end
end

-- Returns the rejection reason from the headers of a 3scale backend response.
-- The header is set only when the authrep call to backend enables the option
-- to get the rejection reason. This is specified in the '3scale-options'
-- header of the request.
local function rejection_reason(response_headers)
  return response_headers and response_headers['3scale-rejection-reason']
end

function _M:handle_backend_response(cached_key, response, ttl)
  ngx.log(ngx.DEBUG, '[backend] response status: ', response.status, ' body: ', response.body)

  self.cache_handler(self.cache, cached_key, response, ttl)

  local authorized = (response.status == 200)
  local unauthorized_reason = not authorized and rejection_reason(response.headers)

  return authorized, unauthorized_reason
end

if custom_config then
  local path = package.path
  local module = gsub(custom_config, '%.lua$', '') -- strip .lua from end of the file
  package.path = package.path .. ';' .. './?.lua;'
  local ok, c = pcall(function() return require(module) end)

  if not ok then
    local chunk, _ = loadfile(custom_config)

    if chunk then
      ok = true
      c =  chunk()
    end
  end

  package.path = path

  if ok then
    if type(c) == 'table' and type(c.setup) == 'function' then
      ngx.log(ngx.DEBUG, 'executing custom config ', custom_config)
      c.setup(_M)
    else
      ngx.log(ngx.ERR, 'failed to load custom config ', custom_config, ' because it does not return table with function setup')
    end
  else
    ngx.log(ngx.ERR, 'failed to load custom config ', custom_config, ' with ', c)
  end
end

return _M
