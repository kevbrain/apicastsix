--- resty.synchronization
-- module to de-duplicate work
-- @classmod resty.synchronization

local semaphore = require "ngx.semaphore"

local rawset = rawset
local setmetatable = setmetatable

local _M = {
  _VERSION = '0.1'
}
local mt = {
  __index = _M
}
--- initialize new synchronization table
-- @tparam int size how many resources for each key
function _M.new(_, size)
  local semaphore_mt = {
    __index = function(t, k)
      local sema = semaphore.new(size or 1)
      sema.name = k
      rawset(t, k, sema)
      return sema
    end
  }


  local semaphores = setmetatable({}, semaphore_mt)
  return setmetatable({ semaphores = semaphores }, mt)
end

--- get semaphore for given key
-- @tparam string key key for the semaphore
-- @treturn resty.semaphore semaphore instance
-- @treturn string key
function _M:acquire(key)
  local semaphores = self.semaphores
  if not semaphores then
    return nil, 'not initialized'
  end
  return semaphores[key], key
end

--- release semaphore
-- to clean up unused semaphores
-- @tparam string key key for the semaphore
function _M:release(key)
  local semaphores = self.semaphores
  if not semaphores then
    return nil, 'not initialized'
  end
  semaphores[key] = nil
end

return _M
