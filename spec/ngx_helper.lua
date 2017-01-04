local busted = require('busted')

local ngx_var = ngx.var

busted.after_each(function()
  ngx.var = ngx_var
end)

busted.teardown(function()
  ngx.var = ngx_var
end)
