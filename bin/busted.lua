if ngx ~= nil then
  ngx.exit = function()end
end

if os.getenv('CI') == 'true' then
  local luacov = require('luacov.runner')
  local pwd = os.getenv('PWD')

  for _, option in ipairs({"statsfile", "reportfile"}) do
    -- properly expand current working dir, workaround for https://github.com/openresty/resty-cli/issues/35
    luacov.defaults[option] = pwd .. package.config:sub(1, 1) .. luacov.defaults[option]
  end

  table.insert(arg, '--coverage')
end

-- Busted command-line runner
require 'busted.runner'({ standalone = false })
