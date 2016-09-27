
local redis = require 'resty.redis'

local _M = {} -- public interface

-- private
-- Logging Helpers
function _M.show_table(t, ...)
  local indent = 0 --arg[1] or 0
  local indentStr=""
  local msg
  for i = 1,indent do indentStr=indentStr.."  " end

  for k,v in pairs(t) do
    if type(v) == "table" then
      msg = indentStr .. _M.show_table(v or '', indent+1)
    else
      msg = indentStr ..  k .. " => " .. v
    end
    _M.log_message(msg)
  end
end

function _M.log_message(str)
  ngx.log(0, str)
end

function _M.newline()
  ngx.log(0,"  ---   ")
end

function _M.log(content)
  if type(content) == "table" then
    _M.log_message(_M.show_table(content))
  else
    _M.log_message(content)
  end
  _M.newline()
end

-- End Logging Helpers

-- Table Helpers
function _M.keys(t)
  local n=0
  local keyset = {}
  for k,v in pairs(t) do
    n=n+1
    keyset[n]=k
  end
  return keyset
end
-- End Table Helpers


function _M.dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then
        k = '"'..k..'"'
      end
      s = s .. '['..k..'] = ' .. _M.dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

function _M.sha1_digest(s)
  local str = require "resty.string"
  return str.to_hex(ngx.sha1_bin(s))
end

-- returns true iif all elems of f_req are among actual's keys
function _M.required_params_present(f_req, actual)
  local req = {}
  for k,v in pairs(actual) do
    req[k] = true
  end
  for i,v in ipairs(f_req) do
    if not req[v] then
      return false
    end
  end
  return true
end

function _M.connect_redis(host, port)
  local h = host or os.getenv('REDIS_HOST') or "127.0.0.1"
  local p = port or os.getenv('REDIS_PORT') or 6379
  local red = redis:new()
  local ok, err = red:connect(h, p)
  if not ok then
    return nil, _M.error("failed to connect to redis on " .. h .. ":" .. p .. ":", err)
  end
  return red
end

-- error and exist
function _M.error(...)
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
  ngx.say(...)
  ngx.exit(ngx.status)
end

function _M.missing_args(text)
  ngx.say(text)
  ngx.exit(ngx.HTTP_OK)
end

---
-- Builds a query string from a table.
--
-- This is the inverse of <code>parse_query</code>.
-- @param query A dictionary table where <code>table['name']</code> =
-- <code>value</code>.
-- @return A query string (like <code>"name=value2&name=value2"</code>).
-----------------------------------------------------------------------------
function _M.build_query(query)
  local qstr = ""

  for i,v in pairs(query) do
    qstr = qstr .. i .. '=' .. v .. '&'
  end
  return string.sub(qstr, 0, #qstr-1)
end

return _M

-- -- Example usage:
-- local MM = require 'mymodule'
-- MM.bar()
