local _M = {
  _VERSION = '0.01',
}

local mt = { __index = _M }

function map(func, tbl)
  local newtbl = {}
  for i,v in pairs(tbl) do
    newtbl[i] = func(v)
  end
  return newtbl
end

function _M.parse_service(service)
  local backend_version = service.backend_version

  return {
      error_auth_failed = service.error_auth_failed,
      error_auth_missing = service.error_auth_missing,
      auth_failed_headers = service.error_headers_auth_failed,
      auth_missing_headers = service.error_headers_auth_missing,
      error_no_match = service.error_no_match,
      no_match_headers = service.error_headers_no_match,
      no_match_status = service.error_status_no_match,
      auth_failed_status = service.error_status_auth_failed,
      auth_missing_status = service.error_status_auth_missing,
      secret_token = service.secret_token,
      get_credentials = function(service, params)
        local credentials
        if backend_version == '1' then
          credentials = params.user_key
        elseif backend_version == '2' then
          credentials = (params.app_id and params.app_key)
        elseif backend_version == 'oauth' then
          credentials = (params.access_token or params.authorization)
        else
          error("Unknown backend version: " .. backend_version)
        end
        return credentials or error_no_credentials(service)
      end,
      extract_usage = function (service, request)
        local method, url = unpack(string.split(request," "))
        local path, querystring = unpack(string.split(url, "?"))
        local usage_t =  {}
        local matched_rules = {}

        local args = get_auth_params(nil, method)

        for i,r in ipairs(service.rules) do
          check_rule({path=path, method=method, args=args}, r, usage_t, matched_rules)
        end

        -- if there was no match, usage is set to nil and it will respond a 404, this behavior can be changed
        return usage_t, table.concat(matched_rules, ", ")
      end,
      rules = map(function(proxy_rule)
        return {
          method = proxy_rule.http_method,
          pattern = proxy_rule.pattern,
          parameters = proxy_rule.parameters,
          querystring_params = function(args)
            return check_querystring_params(proxy_rule.querystring_parameters).presence or true
          end,
          system_name = proxy_rule.metric_system_name,
          delta = proxy_rule.delta
        }
      end, service.proxy_rules or {})
    }
end

function _M.parse(contents, encoder)
  encoder = encoder or require 'cjson'
  local config = encoder.decode(contents)

  return _M.new(config)
end

function _M.new(configuration)
  local services = (configuration or {}).services or {}
  return setmetatable({ services = map(_M.parse_service, services) }, mt)
end

return _M
