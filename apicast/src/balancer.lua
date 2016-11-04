local round_robin = require 'resty.balancer.round_robin'

local _M = { }

function _M.call()
  local balancer = round_robin.new()
  local peers = balancer:peers(ngx.ctx[ngx.var.proxy_host])

  local peer, err = balancer:set_peer(peers)

  if not peer then
    ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
    ngx.log(ngx.ERR, "failed to set current backend peer: ", err)
    ngx.exit(ngx.status)
  end
end

return _M
