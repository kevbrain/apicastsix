if ngx ~= nil then
  ngx.exit = function()end
end

pcall(require, 'luarocks.loader')

-- Busted command-line runner
require 'busted.runner'({ standalone = false })
