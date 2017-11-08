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

local function strip_trailing_slash(path)
  if sub(path, -1) == '/' then
    path = sub(path, 1, len(path) - 1)
  end

  return path
end

local pwd = strip_trailing_slash(env.get('PWD') or util.system('pwd'))

local function abs_path(path)
  local relative_path = sub(path, 1, 1) ~= '/'
  local absolute_path

  if relative_path and pwd then
    absolute_path = format("%s/%s", pwd, path)
  else
    absolute_path = path
  end

  return absolute_path
end

local function is_path(path)
  return path and len(tostring(path)) > 0
end

local function read_path(path)
  return assert(open(path)):read('*a')
end

local function read(path)
  if not is_path(path) then
    return nil, 'invalid or missing path'
  end

  local absolute_path = abs_path(path)

  ngx.log(ngx.INFO, 'configuration loading file ', absolute_path)

  return read_path(absolute_path), absolute_path
end

function _M.call(path)
  local file = path or env.get('THREESCALE_CONFIG_FILE')

  return read(file)
end

return _M
