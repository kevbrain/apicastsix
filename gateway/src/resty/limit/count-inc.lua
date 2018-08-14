-- This file applies a patch from
-- https://github.com/3scale/lua-resty-limit-traffic/commit/c53f2240e953a9656580dbafcc142363ab063100
-- It can be removed when https://github.com/openresty/lua-resty-limit-traffic/pull/34 is merged and released.

local _M = {}
local resty_limit_count = require('resty.limit.count')
local setmetatable = setmetatable

local mt = {
    __index = _M
}

function _M.new(...)
    local lim, err = resty_limit_count.new(...)

    if lim then
        return setmetatable(lim, mt)
    else
        return nil, err
    end
end

function _M.incoming(self, key, commit)
    local dict = self.dict
    local limit = self.limit
    local window = self.window

    local count, err

    if commit then
        count, err = dict:incr(key, 1, 0, window)

        if not count then
            return nil, err
        end

        if count > limit then
            count, err = dict:incr(key, -1)

            if not count then
                return nil, err
            end

            return nil, "rejected"
        end

    else
        count = (dict:get(key) or 0) + 1
    end

    if count > limit then
        return nil, "rejected"
    end

    return 0, limit - count
end

-- uncommit remaining and return remaining value
function _M.uncommit(self, key)
    assert(key)
    local dict = self.dict
    local limit = self.limit

    local count, err = dict:incr(key, -1)
    if not count then
        if err == "not found" then
            count = 0
        else
            return nil, err
        end
    end

    return limit - count
end

return setmetatable(_M, { __index = resty_limit_count })

