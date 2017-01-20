local busted = require('busted')

local ngx_var = ngx.var
local ngx_ctx = ngx.ctx

local function cleanup()
  ngx.var = ngx_var
  ngx.ctx = ngx_ctx
end

busted.after_each(cleanup)
busted.teardown(cleanup)

busted.before_each(function()
  ngx.ctx = { }
end)
