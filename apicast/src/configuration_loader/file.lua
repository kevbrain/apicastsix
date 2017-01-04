local getenv = os.getenv
local len = string.len
local tostring = tostring
local open = io.open
local assert = assert

local _M = {
  _VERSION = '0.1'
}

local function read(path)
  if not path or len(tostring(path)) == 0 then
    return nil, 'missing path'
  end

  ngx.log(ngx.INFO, 'configuration loading file ' .. path)
  return assert(open(path)):read('*a')
end

function _M.call(path)
  local file = path or getenv('THREESCALE_CONFIG_FILE')

  return read(file)
end

return _M
