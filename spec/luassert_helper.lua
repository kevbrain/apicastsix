local busted = require('busted')
local assert = require("luassert")

local snapshot

busted.before_each(function()
  snapshot = assert:snapshot()
end)

busted.after_each(function()
  snapshot:revert()
end)
