local pairs = pairs
local type = type
local assert = assert
local setmetatable = setmetatable
local insert = table.insert
local remove = table.remove
local error = error
local format = string.format

local _M = {}

local function contains(expected, actual)
  if actual == expected then return true end
  local t1,t2 = type(actual), type(expected)
  if t1 ~= t2 then return false, format("can't compare %q with %q", t1, t2) end

  if t1 == 'table' then
    for k,v in pairs(expected) do
      local ok, err = contains(v, actual[k])
      if not ok then
        return false, format('[%q] %s', k, err)
      end
    end
    return true
  end

  return false, format('%q does not match %q', actual, expected)
end


_M.expectation = {}

_M.expectation.new = function(request)
  assert(request, 'needs expected request')
  local expectation = { request = request }

  -- chain function to add a response to expectation
  local mt = { respond_with = function(response) expectation.response = response end }

  return setmetatable(expectation, {__index = mt})
end

_M.expectation.match = function(expectation, request)
  return contains(expectation.request, request)
end

_M.new = function()
  local requests = {}
  local expectations = {}
  local backend = {}

  backend.expect = function(request)
    local expectation = _M.expectation.new(request)
    insert(expectations, expectation)
    return expectation
  end

  backend.send = function(request)
    local expectation = remove(expectations, 1)

    if not expectation then error('no expectation') end
    local match, err = _M.expectation.match(expectation, request)
    if not match then error('expectation does not match: ' .. err) end

    insert(requests, request)

    return expectation.response
  end

  backend.verify_no_outstanding_expectations = function()
    assert(#expectations == 0, 'has ' .. #expectations .. ' outstanding expectations')
  end

  return backend
end

return _M
