local _M = {
  _VERSION = '0.1'
}

function _M.default_port(scheme)
  if scheme == 'http' then
    return 80
  elseif scheme == 'https' then
    return 443
  end
end

function _M.split(url)
  if not url then
    return nil, 'missing endpoint'
  end

  local match = ngx.re.match(url, "^(https?):\\/\\/(?:(.+)@)?([^\\/\\s]+?)(?::(\\d+))?(\\/.+)?$", 'oj')

  if not match then
    return nil, 'invalid endpoint' -- TODO: maybe improve the error message?
  end

  local scheme, userinfo, host, port, path = unpack(match)

  if path == '/' then path = nil end

  match = userinfo and ngx.re.match(tostring(userinfo), "^([^:\\s]+)?(?::(.*))?$", 'oj')
  local user, pass = unpack(match or {})

  return { scheme, user or false, pass or false, host, port or false, path or nil }
end


return _M
