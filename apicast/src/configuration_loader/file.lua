local len = string.len
local format = string.format
local tostring = tostring
local open = io.open
local assert = assert
local sub = string.sub
local util = require 'util'
local env = require 'resty.env'

local _M = {
  _VERSION = '0.1'
}

local pwd = env.get('PWD') or util.system('pwd')

-- strip trailing slash
if pwd and sub(pwd, -1) == '/' then
  pwd = sub(pwd, 1, len(pwd) - 1)
end


local function read(path)
  if not path or len(tostring(path)) == 0 then
    return nil, 'missing path'
  end

  local relative_path = sub(path, 1, 1) ~= '/'
  local absolute_path

  if relative_path and pwd then
    absolute_path = format("%s/%s", pwd, path)
  else
    absolute_path = path
  end

  ngx.log(ngx.INFO, 'configuration loading file ' .. absolute_path)

  return assert(open(absolute_path)):read('*a'), absolute_path
end

function _M.call(path)
  local file = path or env.get('THREESCALE_CONFIG_FILE')

  return read(file)
end

return _M
