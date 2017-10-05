local round_robin = require 'resty.balancer.round_robin'

local _M = { default_balancer = round_robin.new() }

function _M.call(_, balancer)
  balancer = balancer or _M.default_balancer
  local host = ngx.var.proxy_host -- NYI: return to lower frame
  local peers = balancer:peers(ngx.ctx[host])

  local peer, err = balancer:set_peer(peers)

  if not peer then
    ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
    ngx.log(ngx.ERR, "failed to set current backend peer: ", err)
    ngx.exit(ngx.status)
  end
end

return _M
