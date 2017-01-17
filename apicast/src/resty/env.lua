local _M = {
  _VERSION = '0.1'
}

local getenv = os.getenv

local function fetch(name)
  local value = getenv(name)

  _M.env[name] = value

  return value
end

function _M.get(name)
  return _M.env[name] or fetch(name)
end

local env_mapping = {
  ['true'] = true,
  ['false'] = false,
  ['1'] = true,
  ['0'] = false,
  [''] = false
}

function _M.enabled(name)
  return env_mapping[_M.get(name)]
end

function _M.set(name, value)
  local env = _M.env
  local previous = env[name]
  env[name] = value
  return previous
end

function _M.reset()
  _M.env = {}
  return _M
end

return _M.reset()
