--- @module resty.concurrent

local ngx_semaphore = require('ngx.semaphore')
local setmetatable = setmetatable
local rawset = rawset

--- @type Event
-- Object that can be resolved just once and wakes up all threads waiting for it.
local _M = { }
local mt = { __index = _M }

local huge = 2147483647
local max_timeout_seconds = huge/1000

local yield = function() ngx.sleep(0) end

--- @treturn Event
--- @static
function _M.new()
    return setmetatable({ _set = false, sema = ngx_semaphore.new(0) }, mt)
end

--- @treturn Event
function _M:set()
    local sema = self and self.sema
    if not sema then return nil, 'not initialized' end

    rawset(self, '_set', true)
    sema:post(huge)
    yield()

    return true
end

--- @treturn boolean, string
---@param timeout number how many seconds to wait
function _M:wait(timeout)
    local sema = self and self.sema

    if rawget(self, '_set') then
        return true
    else
        return sema:wait(timeout or max_timeout_seconds)
    end
end

return _M
