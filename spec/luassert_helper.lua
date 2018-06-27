local busted = require('busted')
local assert = require("luassert")
local util = require ('luassert.util')
local say = require('say')

do -- set up reverting stubs
  local snapshot

  busted.before_each(function()
    snapshot = assert:snapshot()
  end)

  busted.after_each(function()
    snapshot:revert()
  end)
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
