local _M = {}

local value_of = {
  request_method = function() return ngx.req.get_method() end,
  request_host = function() return ngx.var.host end,
  request_path = function() return ngx.var.uri end
}

function _M.evaluate(expression)
  local match_attr = ngx.re.match(expression, [[^([\w]+)$]], 'oj')

  if match_attr then
    return value_of[match_attr[1]]()
  end

  local match_attr_and_value = ngx.re.match(expression, [[^([\w]+) == "([\w/]+)"$]], 'oj')

  if not match_attr_and_value then
    return nil, 'Error while parsing the condition'
  end

  local entity = match_attr_and_value[1]
  local value = match_attr_and_value[2]

  return value_of[entity]() == value
end

return _M
