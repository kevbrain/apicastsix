local round_robin = require 'resty.balancer.round_robin'
local resty_url = require 'resty.url'
local empty = {}

local _M = { default_balancer = round_robin.new() }

local function get_default_port(upstream_url)
  local url = resty_url.split(upstream_url) or empty
  local scheme = url[1] or 'http'
  return resty_url.default_port(scheme)
end

local function exit_service_unavailable()
  ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
  ngx.exit(ngx.status)
end

function _M.call(_, _, balancer)
  balancer = balancer or _M.default_balancer
  local host = ngx.var.proxy_host -- NYI: return to lower frame
  local peers = balancer:peers(ngx.ctx[host])

  local peer, err = balancer:select_peer(peers)

  if not peer then
    ngx.log(ngx.ERR, 'could not select peer: ', err)
    return exit_service_unavailable()
  end

  local address, port = peer[1], peer[2]

  if not address then
    ngx.log(ngx.ERR, 'peer missing address')
    return exit_service_unavailable()
  end

  if not port then
    port = get_default_port(ngx.var.proxy_pass)
  end

  local ok
  ok, err = balancer.balancer.set_current_peer(address, port)

  if not ok then
    ngx.log(ngx.ERR, 'failed to set current backend peer: ', err)
    return exit_service_unavailable()
  end

  ngx.log(ngx.INFO, 'balancer set peer ', address, ':', port)
end

return _M
