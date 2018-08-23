local setmetatable = setmetatable

local _M = { }
local mt = { __index = _M }

local function configure(cmd)
  cmd:argument('file', 'file to execute'):args("?")
  return cmd
end

function _M.new(parser)
  local cmd = configure(parser:command('console', 'Start console'))

  return setmetatable({ parser = parser, cmd = cmd }, mt)
end

function mt.__call(_, options)
  local repl = require('resty.repl')

  _G.repl = repl.start

  function _G.reload() package.loaded = {} end

  if options.file then
    dofile(options.file)
  end

  repl.start()
end

return setmetatable(_M, mt)
