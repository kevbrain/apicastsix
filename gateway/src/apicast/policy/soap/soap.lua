--- SOAP Policy
-- This policy adds support for a very small subset of SOAP.
-- This policy basically expects a SOAPAction URI in the SOAPAction header or
-- the content-type header.
-- The SOAPAction header is used in v1.1 of the SOAP standard:
-- https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383528, whereas the
-- Content-Type header is used in v1.2 of the SOAP standard:
-- https://www.w3.org/TR/soap12-part2/#ActionFeature
-- The SOAPAction URI is matched against the mapping rules defined in the
-- policy and calculates a usage based on that so it can be authorized and
-- reported against 3scale's backend.

local sub = string.sub
local len = string.len
local lower = string.lower
local ipairs = ipairs
local insert = table.insert

local MappingRule = require('apicast.mapping_rule')
local Usage = require('apicast.usage')
local mapping_rules_matcher = require('apicast.mapping_rules_matcher')

local policy = require('apicast.policy')

local _M = policy.new('SOAP policy')

local soap_action_header = 'SOAPAction'
local soap_action_ctype = 'application/soap+xml;'

local new = _M.new

local function starts_with(str, start)
  return sub(str, 1, len(start)) == start
end

-- Extracts a SOAP action from the SOAPAction header. Returns nil when not
-- present.
local function soap_action_in_header(headers)
  return headers[soap_action_header]
end

local regex_del_leading_spaces = [[^\s*]]
local regex_del_spaces_around_semicolon = [[\s*;\s*]]

-- There can be spaces in the Content-Type, values can be wrapped with '"',
-- etc.
-- See: https://tools.ietf.org/html/rfc7231#section-3.1.1.1
local regex_action_from_ctype = [[action=(?:"(.+)"|([^;"]+))\s*(?:;|$)]]

-- Extracts the SOAP action from a string that contains the parameters of a
-- Content-Type header. The string has this format:
-- a_param=x;action=soap_action;another_param=y
-- This method returns the value of 'action' or nil when it's not present.
local function soap_action_from_ctype_params(ctype_params)
  local params = ngx.re.sub(
    ctype_params, regex_del_leading_spaces, '', 'oj')

  local params_without_blanks = ngx.re.gsub(
    params, regex_del_spaces_around_semicolon, ';', 'oj')

  local matches = ngx.re.match(
    lower(params_without_blanks), regex_action_from_ctype, 'oj')

  if not matches then return nil end
  return matches[1] or matches[2] -- There are 2 paranthesized captures
end

-- Extracts a SOAP action from the Content-Type header. In SOAP, the
-- type/subtype is application/soap+xml, and the action is specified as a
-- param in that header. When there is no SOAP action, this method returns nil.
local function soap_action_in_ctype(headers)
  local ctype = headers['Content-Type']

  -- The Content-Type can be a mix of upper and lower-case chars. Convert it to
  -- include only lower-case chars to be able to compare it.
  if ctype and starts_with(lower(ctype), soap_action_ctype) then
    local header_params = sub(ctype, len(soap_action_ctype) + 1, -1)
    return soap_action_from_ctype_params(header_params)
  else
    return nil
  end
end

-- Extracts a SOAP action URI from the SOAP Action and the Content-Type
-- headers. When both contain a SOAP action, the Content-Type one takes
-- precedence.
local function extract_soap_uri()
  local headers = ngx.req.get_headers() or {}
  return soap_action_in_ctype(headers) or soap_action_in_header(headers)
end

local function usage_from_matching_rules(soap_action_uri, rules)
  return mapping_rules_matcher.get_usage_from_matches(
    nil, soap_action_uri, {}, rules)
end

local function mapping_rules_from_config(config)
  if not (config and config.mapping_rules) then return {} end

  local res = {}

  for _, config_rule in ipairs(config.mapping_rules) do
    local rule = MappingRule.from_proxy_rule(config_rule)
    insert(res, rule)
  end

  return res
end

--- Initialize a SOAP policy
-- @tparam[opt] table config Configuration
function _M.new(config)
  local self = new(config)
  self.mapping_rules = mapping_rules_from_config(config)
  return self
end

--- Rewrite phase
-- When a SOAP Action is received via the SOAPAction or the Content-Type
-- headers, the policy matches it against the mapping rules defined in the
-- configuration of the policy and calculates the associated usage.
-- This usage is merged with the one received in the shared context.
-- @tparam table context Shared context between policies
function _M:rewrite(context)
  local soap_action_uri = extract_soap_uri()

  if soap_action_uri then
    local soap_usage = usage_from_matching_rules(
      soap_action_uri, self.mapping_rules)

    context.usage = context.usage or Usage.new()
    context.usage:merge(soap_usage)
  end
end

return _M
