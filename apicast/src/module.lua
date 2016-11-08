local setmetatable = setmetatable
local pcall = pcall
local require = require
local pairs = pairs
local type = type

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(name)
  name = name or os.getenv('APICAST_MODULE') or 'apicast'

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

  local fun = _M.load(name, phase)

  if fun then
    ngx.log(ngx.DEBUG, 'plugin ', name, ' calling phase ', phase)
    return fun(...)
  else
    ngx.log(ngx.DEBUG, 'plugin ', name, ' skipping phase ', phase)
    return nil, 'plugin does not have ' .. phase
  end
end

local cache = {}
local prequire = function(file)

  if cache[file] then
    return true, cache[file]
  end

  local ok, mod = pcall(require, file)

  if ok then
    cache[file] = mod
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

  return  ok, mod
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

      local f = ret[method]

      if f then
        return f
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

return _M
