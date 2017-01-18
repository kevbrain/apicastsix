local configuration = require 'configuration'
local cjson = require 'cjson'

local type = type
local pcall = pcall
local len = string.len

local _M = {

}

function _M.decode(contents, encoder)
  if not contents then return nil end
  if type(contents) == 'string' and len(contents) == 0 then return nil end
  if type(contents) == 'table' then return contents end
  if contents == '\n' then return nil end

  encoder = encoder or cjson

  local ok, ret = pcall(encoder.decode, contents)

  if not ok then
    return nil, ret
  end

  if ret == encoder.null then
    return nil
  end

  return ret
end


function _M.encode(contents, encoder)
  if type(contents) == 'string' then return contents end

  encoder = encoder or cjson

  return encoder.encode(contents)
end

function _M.parse(contents, encoder)
  local config, err = _M.decode(contents, encoder)

  if config then
    return configuration.new(config)
  else
    return nil, err
  end
end

return _M
