local busted = require('busted')
local assert = require('luassert.assert')
local util = require ('luassert.util')
local say = require('say')

do -- set up reverting stubs
  local state = require("luassert.state")

  local function snapshot()
    --- creates a snapshot and adds it to a stack
    state.snapshot()
    return nil, true -- to not stop the chain
  end

  local function revert()
    --- reverts state of the current snapshot and removes it from the stack
    state.revert()
    return nil, true
  end

  for _, phase in ipairs({ 'suite', 'file', 'describe', 'it'}) do
    busted.subscribe({ phase, 'start' }, snapshot)
    busted.subscribe({ phase, 'end' }, revert)
  end

  busted.before_each(snapshot)
  busted.after_each(revert)
end

do -- adding gt matcher: assert.spy(something).was_called_with(match.is_gt(4))
  local function is_gt(_, arguments)
    local expected = arguments[1]
    return function(value)
      return value > expected
    end
  end

  assert:register("matcher", "gt", is_gt)
end

do -- adding assert.returns_error(error_text, ok, ret) : assert.returns_error('not initialized', _M:call())
  local tostring = tostring
  local tonumber = tonumber

  local function returns_error(state, arguments, level)
    local argc = arguments.n
    assert(argc == 3, say("assertion.internal.argtolittle", { "error_matches", 3, tostring(argc) }), level)

    local expected = tonumber(arguments[1])
    local ok = tonumber(arguments[2])
    local actual = tonumber(arguments[3])

    local result = not ok and expected == actual
    -- switch arguments for proper output message
    util.tinsert(arguments, 1, util.tremove(arguments, 3))
    state.failure_message = arguments[3]
    return result
  end

  assert:register("assertion", "returns_error", returns_error, "assertion.error.positive", "assertion.error.negative")
end
