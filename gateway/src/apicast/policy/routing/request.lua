local setmetatable = setmetatable

local _M = {}

local mt = { __index = _M }

function _M.new()
  local self = setmetatable({}, mt)
  return self
end

function _M:get_uri()
  self.uri = self.uri or ngx.var.uri
  return self.uri
end

function _M:get_header(name)
  self.headers = self.headers or ngx.req.get_headers()
  return self.headers[name]
end

function _M:get_uri_arg(name)
  self.query_args = self.query_args or ngx.req.get_uri_args()
  return self.query_args[name]
end

function _M:set_validated_jwt(jwt)
  self.jwt = jwt
end

function _M:get_validated_jwt()
  return self.jwt
end

return _M
