local TAP = require('busted.outputHandlers.TAP')
local JUnit = require('busted.outputHandlers.junit')


return function(options)
  local handler = require 'busted.outputHandlers.base'()

  local tap = TAP(setmetatable({ }, { __index = options }))
  local junit = JUnit(setmetatable({
    arguments = { os.getenv('JUNIT_OUTPUT_FILE') },
  }, { __index = options }))

  function handler.subscribe(_, ...)
    tap:subscribe(...)
    junit:subscribe(...)
  end

  return handler
end
