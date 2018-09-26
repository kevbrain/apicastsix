local assert = assert
local backend = {}
local response = require 'resty.http_ng.response'
local Upstream = require('apicast.upstream')
local http_proxy = require 'resty.http.proxy'

local METHODS = {
  ["GET"]      = ngx.HTTP_GET,
  ["HEAD"]     = ngx.HTTP_HEAD,
  ["PATCH"]    = ngx.HTTP_PATCH,
  ["PUT"]      = ngx.HTTP_PUT,
  ["POST"]     = ngx.HTTP_POST,
  ["DELETE"]   = ngx.HTTP_DELETE,
  ["OPTIONS"]  = ngx.HTTP_OPTIONS
}

local PROXY_LOCATION = '/___http_call'
local pairs = pairs

backend.capture = ngx.location.capture
backend.send = function(_, request)
  if http_proxy.active(request) then
    return response.error(request, 'ngx backend does not support proxy')
  end

  local res = backend.capture(PROXY_LOCATION, {
    method = METHODS[request.method],
    body = request.body,
    ctx = {
      headers = request.headers,
      url = request.url,
    },
    vars = {
      version = ngx.var.version,
    }
  })

  -- if res.truncated then
    -- Do what? what error message it should say?
  -- end

  return response.new(request, res.status, res.header, res.body)
end

local balancer = require('apicast.balancer')

function backend.balancer()
  return assert(balancer:call(ngx.ctx))
end

function backend.resolver()
  local upstream = assert(Upstream.new(ngx.ctx.url))

  upstream.upstream_name = 'http_client'
  upstream.location_name = nil

  local headers = ngx.ctx.headers

  for name, _ in pairs(headers) do
    ngx.req.set_header(name, headers[name])
  end

  ngx.req.set_uri('/') -- reset the original PROXY_LOCATION path
  ngx.var.connection_header = headers.connection
  ngx.var.host_header = headers.host
  ngx.var.options = headers['3scale-options']
  ngx.var.grant_type = headers['X-3scale-OAuth2-Grant-Type']

  upstream:call(ngx.ctx)
end

return backend
