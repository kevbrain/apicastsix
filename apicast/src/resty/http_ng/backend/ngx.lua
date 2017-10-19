local backend = {}
local response = require 'resty.http_ng.response'

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
local ngx_re = require("ngx.re")

backend.capture = ngx.location.capture
backend.send = function(_, request)
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

local balancer = require('balancer')
local resty_resolver = require('resty.resolver')
local resty_url = require('resty.url')

function backend:balancer()
  return balancer:call()
end

local function split_path(path)
  local res, err = ngx_re.split(path, '\\?', nil, nil, 2)

  if res then return res else return nil, err end
end

function backend:resolver()
  local uri = assert(resty_url.parse(ngx.ctx.url))

  ngx.ctx.http_client = resty_resolver:instance():get_servers(uri.host,
    { port = uri.port or resty_url.default_port(uri.scheme) })
  ngx.req.set_header('Host', uri.host)

  local headers = ngx.ctx.headers

  local res = assert(split_path(uri.path))

  if res then
    ngx.req.set_uri(res[1])
    ngx.req.set_uri_args(res[2])
  end

  for name, _ in pairs(headers) do
    ngx.req.set_header(name, headers[name])
  end

  ngx.var.connection_header = headers.connection
  ngx.var.host_header = headers.host
  ngx.var.endpoint = uri.scheme .. '://http_client'
  ngx.var.options = headers['3scale-options']
  ngx.var.grant_type = headers['X-3scale-OAuth2-Grant-Type']
end

return backend
