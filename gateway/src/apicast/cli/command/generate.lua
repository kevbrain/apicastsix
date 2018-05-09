local setmetatable = setmetatable

local filesystem = require('apicast.cli.filesystem')
local pl = require'pl.import_into'()
local Template = require('apicast.cli.template')

local _M = { }
local mt = { __index = _M }

function mt.__call(_) end

local function configure(cmd)
  cmd:command_target("_command")

  require('apicast.cli.command.generate.policy')(cmd)

  return cmd
end

function _M.new(parser)
  local cmd = configure(parser:command('generate', 'Generate scaffolding'))

  return setmetatable({ parser = parser, cmd = cmd }, mt)
end

function _M.copy(source, destination, env, force)
  print('source: ', source)
  print('destination: ', destination)
  print('')

  local template = Template:new(env, source, true)

  for filename in filesystem(source) do
    local path = template:interpret(pl.path.relpath(filename, source))

    local fullpath = pl.path.join(destination, path)

    if pl.path.exists(fullpath) and not force then
      print('exists: ', path)
    elseif pl.path.isdir(filename) then
      assert(pl.dir.makepath(fullpath))
      print('created: ', path)
    else
      assert(pl.file.write(fullpath, template:render(filename)))
      print('created: ', path)
    end
  end
end


return setmetatable(_M, mt)
