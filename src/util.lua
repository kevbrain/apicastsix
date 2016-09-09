local _M = {
  VERSION = '0.0.1'
}

function _M.system(command)
  local tmpname = os.tmpname()
  local success, exit, code = os.execute(command .. ' > ' .. tmpname)

  -- os.execute returns exit code as first return value on OSX
  -- even though the documentation says otherwise (true/false)
  if success == 0 or success then
    local handle, err = io.open(tmpname)

    if handle then
      local output = handle:read("*a")

      handle:close()

      return output
    else
      return nil, err
    end
  else
    return false, exit, code
  end
end

return _M
