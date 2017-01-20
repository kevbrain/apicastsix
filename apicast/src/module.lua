local setmetatable = setmetatable
local pcall = pcall
local require = require
local dofile = dofile
local pairs = pairs
local type = type

local env = require 'resty.env'

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(name)
  name = name or env.get('APICAST_MODULE') or 'apicast'

  ngx.log(ngx.DEBUG, 'init plugin ', name)
  return setmetatable({
    name = name
  }, mt)
end

function _M.call(self, phase, ...)
  -- shortcut for requre('module').call()
  if not self and not phase then
    return _M.new():call()
  end

  -- normal instance interface
  local name = self.name

  if not name then
    return nil, 'not initialized'
  end

  phase = phase or ngx.get_phase()

  local fun, mod = _M.load(name, phase)

  if fun then
    if mod then
      ngx.log(ngx.DEBUG, 'plugin ', name, ' calling instance phase ', phase)
      return fun(mod, ...)
    else
      ngx.log(ngx.DEBUG, 'plugin ', name, ' calling phase ', phase)
      return fun(...)
    end
  else
    ngx.log(ngx.DEBUG, 'plugin ', name, ' skipping phase ', phase)
    return nil, 'plugin does not have ' .. phase
  end
end

local cache = {}

function _M.flush()
  cache = {}
end

local prequire = function(file)

  if cache[file] then
    return true, cache[file]
  end

  local ok, ret = pcall(require, file)

  if not ok and ret then
    -- dofile can load absolue paths, require can't
    ok, ret = pcall(dofile, file)
  end

  if type(ret) == 'userdata' then
    ngx.log(ngx.WARN, 'cyclic require detected: ', debug.traceback())
    return false, ret
  end

  if ok then
    cache[file] = ret
  else
    -- We need to cache that we tried requiring and failed so we do not try
    -- again. If we don't, we'll call require() on each request. This greatly
    -- affects performance.
    -- We can't set cache[file] to nil. That's the same as saying that it is
    -- not cached. We can't set it to an empty table either. Otherwise, the
    -- load() method below will log errors because it'll think that the plugin
    -- exists but it does not define the method.
    cache[file] = 0
  end

  return  ok, ret
end

function _M.load(name, phase)
  local files = {
    [ name .. '.' .. phase ] = 'call', -- like apicast.init exposing .call
    [ name ] = phase -- like apicast exposing .init
  }

  for file, method in pairs(files) do
    local ok, ret = prequire(file)

    if ok and type(ret) == 'table' then
      ngx.log(ngx.DEBUG, 'plugin loaded: ', file)

      local new = ret.new
      local mod

      local f = ret[method]

      if phase ~= 'init' then
        mod = ngx.ctx.module

        if new and not mod then
          ngx.log(ngx.DEBUG, 'initializing mod ', file, ' phase: ', phase)
          mod = new()
          ngx.ctx.module = mod
        end

        if mod then
          f = mod[method] or f
        end
      end

      if f then
        return f, mod
      else
        ngx.log(ngx.ERR, 'plugin ', file, ' missing function ', method)
      end
    elseif ok and not ret then
      ngx.log(ngx.ERR, 'plugin ', file, ' wasnt loaded ', method)
    else
      ngx.log(ngx.DEBUG, 'plugin not loaded: ', file)
    end
  end

  return nil, 'could not load plugin'
end

function _M:require()
  local name = self.name

  if not name then
    return nil, 'not initialized'
  end

  local ok, ret = prequire(name)

  if ok and ret then return ret
  else return ok, ret end
end

return _M
