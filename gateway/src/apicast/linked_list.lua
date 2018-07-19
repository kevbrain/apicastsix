local setmetatable = setmetatable
local error = error

local _M = {

}

local noop = function() end


local empty_t = setmetatable({}, { __newindex = noop })
local __index = function(t,k)
    if t.current[k] == nil then return t.next[k] else return t.current[k] end
end

local ro_mt = {
    __index = __index,
    __newindex = function()
        error("readonly list")
    end,
}

local rw_mt = {
    __index = __index,
    __newindex = function(t, k, v)
        t.current[k] = v
    end
}

local function linked_list(item, next, mt)
    return setmetatable({
        current = item or empty_t,
        next = next or empty_t
    }, mt)
end

local function readonly_linked_list(item, next)
    return linked_list(item, next, ro_mt)
end

local function readwrite_linked_list(item, next)
    return linked_list(item, next, rw_mt)
end

_M.readonly = readonly_linked_list
_M.readwrite = readwrite_linked_list

return _M
