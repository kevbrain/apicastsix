local _M = {
  VERSION = '0.0.1'
}

local ngx_now = ngx.now

local sub = string.sub
local find = string.find
local insert = table.insert

local open = io.open
local execute = os.execute
local tmpname = os.tmpname
local unpack = unpack

function _M.timer(name, fun, ...)
  local start = ngx_now()
  ngx.log(ngx.INFO, 'benchmark start ' .. name .. ' at ' .. start)
  local ret = { fun(...) }
  local time = ngx_now() - start
  ngx.log(ngx.INFO, 'benchmark ' .. name .. ' took ' .. time)
  return unpack(ret)
end
local inspect = require 'inspect'
function _M.system(command)
  local tmpname = tmpname()
  ngx.log(ngx.DEBUG, 'os execute ' .. command)
  local success, exit, code = execute(command .. ' > ' .. tmpname .. ' 2>&1')

  local handle, err = open(tmpname)
  local output

  if handle then
    output = handle:read("*a")
    handle:close()
  else
    return nil, err
  end

  -- os.execute returns exit code as first return value on OSX
  -- even though the documentation says otherwise (true/false)
  if success == 0 or success == true then
    return output
  else
    return nil, output, code or exit or success
  end
end

function _M.string_split(string, delimiter)
  local result = { }
  local from = 1
  local delim_from, delim_to = find( string, delimiter, from )

  if delim_from == nil then return { string } end

  while delim_from do
    insert( result, sub( string, from , delim_from-1 ) )
    from = delim_to + 1
    delim_from, delim_to = find( string, delimiter, from )
  end

  insert( result, sub( string, from ) )

  return result
end

return _M
