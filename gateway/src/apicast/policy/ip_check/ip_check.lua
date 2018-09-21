local iputils = require("resty.iputils")

local policy = require('apicast.policy')
local _M = policy.new('IP check policy')

local new = _M.new

local default_err_msg = 'IP address not allowed'

local function parse_cidrs(cidrs)
  return iputils.parse_cidrs(cidrs or {})
end

local function request_ip_addr()
  return ngx.var.remote_addr
end

local function req_ip_in_range(cidrs)
  return iputils.ip_in_cidrs(request_ip_addr(), cidrs)
end

local function deny_request(error_msg)
  ngx.status = ngx.HTTP_FORBIDDEN
  ngx.say(error_msg)
  ngx.exit(ngx.status)
end

local function apply_whitelist(self)
  if not req_ip_in_range(self.ips) then
    deny_request(self.error_msg)
  end
end

local function apply_blacklist(self)
  if req_ip_in_range(self.ips) then
    deny_request(self.error_msg)
  end
end

local noop = function() end

local check_ips_function = {
  blacklist = apply_blacklist,
  whitelist = apply_whitelist
}

function _M.new(config)
  local self = new(config)

  local conf = config or {}

  self.ips = parse_cidrs(conf.ips) or {}
  self.error_msg = conf.error_msg or default_err_msg

  local check_type = conf.check_type
  self.check_ips = check_ips_function[check_type] or noop

  return self
end

function _M:access()
  self:check_ips()
end

return _M
