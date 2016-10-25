local setmetatable = setmetatable
local pcall = pcall
local require = require
local pairs = pairs

local _M = {
  _VERSION = '0.1'
}

local mt = { __index = _M }

function _M.new(name)
  local name = name or os.getenv('APICAST_MODULE') or 'apicast'

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

  local phase = phase or ngx.get_phase()

  local fun = _M.load(name, phase)

  if fun then
    ngx.log(ngx.DEBUG, 'plugin ', name, ' calling phase ', phase)
    return fun(...)
  else
    ngx.log(ngx.DEBUG, 'plugin ', name, ' skipping phase ', phase)
    return nil, 'plugin does not have ' .. phase
  end
end

local prequire = function(file) return pcall(require, file) end

function _M.load(name, phase)
  local files = {
    [ name .. '.' .. phase ] = 'call', -- like apicast.init exposing .call
    [ name ] = phase -- like apicast exposing .init
  }

  for file, name in pairs(files) do
    local ok, ret = prequire(file)

    if ok then
      ngx.log(ngx.DEBUG, 'plugin loaded: ', file)

      local f = ret[name]

      if f then
        return f
      else
        ngx.log(ngx.ERR, 'plugin ', file, ' missing function ', name)
      end
    else
      ngx.log(ngx.DEBUG, 'plugin not loaded: ', file)
    end
  end

  return nil, 'could not load plugin'
end

return _M
