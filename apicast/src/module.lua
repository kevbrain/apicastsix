local xpcall = xpcall
local require = require
local dofile = dofile
local type = type

local env = require 'resty.env'

local function error_message(error)
  ngx.log(ngx.DEBUG, error)
  return error
end

local prequire = function(file)
  local ok, ret = xpcall(require, error_message, file)
  local prev

  if not ok and ret then
    prev = ret
    -- dofile can load absolute paths, require can't
    ok, ret = xpcall(dofile, error_message, file)
  end

  if not ok and ret then
    if type(ret) == 'userdata' then
      ngx.log(ngx.WARN, 'cyclic require detected: ', debug.traceback())
    elseif prev then
      ngx.log(ngx.WARN, prev)
    end
    return false, ret
  end

  return ok, ret
end

local name = env.get('APICAST_MODULE') or 'apicast'

local ok, mod = prequire(name)

if ok and mod then
  if type(mod) == 'table' then
    if mod.new then
      return mod.new()
    else
      return mod
    end
  else
    ngx.log(ngx.ERR, 'module ', name, ' did not return a table but: ', type(mod))
    return false
  end
else
  return ok, mod
end
