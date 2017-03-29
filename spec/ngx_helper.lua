local busted = require('busted')

local ngx_var = ngx.var
local ngx_ctx = ngx.ctx
local ngx_shared = ngx.shared

local function cleanup()
  ngx.var = ngx_var
  ngx.ctx = ngx_ctx
  ngx.shared = ngx_shared
end

busted.after_each(cleanup)
busted.teardown(cleanup)

busted.before_each(function()
  ngx.ctx = { }
end)
