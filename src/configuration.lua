local _M = {
  _VERSION = '0.01',
}

local mt = { __index = _M }

function _M.parse(contents, encoder)
  encoder = encoder or require 'cjson'
  local config = encoder.decode(contents)

  return _M.new(config)
end

function _M.new(configuration)
  local services = (configuration or {}).services or {}
  return setmetatable({ services = services }, mt)
end

return _M
