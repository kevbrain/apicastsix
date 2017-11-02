local insert = table.insert
local concat = table.concat
local assert = assert
local pairs = pairs
local rawset = rawset
local rawget = rawget
local setmetatable = setmetatable
local getmetatable = getmetatable
local type = type
local lower = string.lower
local upper = string.upper
local ngx_re = ngx.re

local normalize_exceptions = {
  etag = 'ETag'
}

local headers = {}
local headers_mt = {
  __newindex = function(table, key, value)
    rawset(table, headers.normalize_key(key), headers.normalize_value(value))
    return value
  end,
  __index = function(table, key)
    return rawget(table, headers.normalize_key(key))
  end
}

local regex_first_letter = [[^\w]]
local upper_first_match = function(matches) return upper(matches[0]) end

local capitalize = function(string)
  local str = ngx_re.sub(string, regex_first_letter, upper_first_match, 'jo')
  return str
end

local regex_parts = [[[^_-]+]]

local key_parts_capitalized = function(key)
  local parts = {}

  for matches in ngx_re.gmatch(key, regex_parts, 'jo') do
    insert(parts, capitalize(matches[0]))
  end

  return parts
end

headers.normalize_key = function(key)
  local exception = normalize_exceptions[lower(key)]

  if exception then
    return exception
  end

  return concat(key_parts_capitalized(key), '-')
end

local header_mt = {
  __tostring = function(t)
    local tmp = {}

    for k,v in pairs(t) do
      if type(k) == 'string' then
        insert(tmp, k)
      elseif type(v) == 'string' then
        insert(tmp, v)
      end
    end

    return concat(tmp, ', ')
  end
}

headers.normalize_value = function(value)
  if type(value) == 'table' and getmetatable(value) == nil then
    return setmetatable(value, header_mt)
  else
    return value
  end
end

headers.normalize = function(http_headers)
  http_headers = http_headers or {}

  local normalized = {}
  for k,v in pairs(http_headers) do
    normalized[headers.normalize_key(k)] = headers.normalize_value(v)
  end

  return normalized
end

headers.new = function(h)
  local normalized = assert(headers.normalize(h or {}))

  return setmetatable(normalized, headers_mt)
end

return headers
