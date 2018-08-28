-- This is a simple policy. The only thing it does is log when it runs each of
-- the nginx phases. It's useful when testing to make sure that all the phases
-- are executed.

local policy = require('apicast.policy')
local _M = policy.new('Phase logger')

local new = _M.new

local log_levels = {
  stderr = ngx.STDERR,
  emerg = ngx.EMERG,
  alert = ngx.ALERT,
  crit = ngx.CRIT,
  err = ngx.ERR,
  error = ngx.ERR,
  warn = ngx.WARN,
  notice = ngx.NOTICE,
  info = ngx.INFO,
  debug = ngx.DEBUG,
  default = ngx.DEBUG,
}

function _M.new(configuration)
  local self = new(configuration)
  local level

  if configuration then
    level = log_levels[configuration.log_level]
  end

  self.level = level or log_levels.default

  return self
end

for _, phase in policy.phases() do
  _M[phase] = function(self) ngx.log(self.level, 'running phase: ', phase) end
end

return _M
