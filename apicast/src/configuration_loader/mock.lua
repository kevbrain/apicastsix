local _M = {
  _VERSION = '0.1',
  config = false
}

function _M.call()
  return _M.config
end

function _M.save(config)
  _M.config = config
end

return _M
