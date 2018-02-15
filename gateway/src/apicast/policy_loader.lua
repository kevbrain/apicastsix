--- Policy loader
-- This module loads a policy defined by its name and version.
-- It uses sandboxed require to isolate dependencies and not mutate global state.
-- That allows for loading several versions of the same policy with different dependencies.
-- And even loading several independent copies of the same policy with no shared state.
-- Each object returned by the loader is new table and shares only shared APIcast code.

local sandbox = require('resty.sandbox')

local format = string.format
local ipairs = ipairs
local insert = table.insert
local setmetatable = setmetatable
local pcall = pcall

local _M = {}

local resty_env = require('resty.env')
local re = require('ngx.re')

do
  local function apicast_dir()
    return resty_env.value('APICAST_DIR') or '.'
  end

  local function policy_load_path()
    return resty_env.value('APICAST_POLICY_LOAD_PATH') or
      format('%s/policies', apicast_dir())
  end

  function _M.policy_load_paths()
    return re.split(policy_load_path(), ':', 'oj')
  end

  function _M.builtin_policy_load_path()
    return resty_env.value('APICAST_BUILTIN_POLICY_LOAD_PATH') or format('%s/src/apicast/policy', apicast_dir())
  end
end

function _M:call(name, version, dir)
  local v = version or 'builtin'
  local load_paths = {}

  for _, path in ipairs(dir or self.policy_load_paths()) do
    insert(load_paths, format('%s/%s/%s/?.lua', path, name, v))
  end

  if v == 'builtin' then
    insert(load_paths, format('%s/%s/?.lua', self.builtin_policy_load_path(), name))
  end

  local loader = sandbox.new(load_paths)

  ngx.log(ngx.DEBUG, 'loading policy: ', name, ' version: ', v)

  -- passing the "exclusive" flag for the require so it does not fallback to native require
  -- it should load only policies and not other code and fail if there is no such policy
  return loader('init', true)
end

function _M:pcall(name, version, dir)
  local ok, ret = pcall(self.call, self, name, version, dir)

  if ok then
    return ret
  else
    return nil, ret
  end
end

return setmetatable(_M, { __call = _M.call })
