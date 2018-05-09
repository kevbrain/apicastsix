local generate = require('apicast.cli.command.generate')
local pl = require'pl.import_into'()

local function call(options)
  generate.copy(options.template, options.apicast, {
    _brackets = '{}',
    policy = {
      file = options.name,
      name = options.name,
      version = options.version,
      summary = options.summary,
    }
  }, options.force)
end

local directory = function(dir) if pl.path.dir(dir) then return pl.path.abspath(dir) end end

return function(parser)
  local cmd = parser:command('policy', 'create new policy')

  cmd:argument('name', 'a name of the new policy')

  cmd:option('--summary', 'Policy summary')
    :default('TODO: write policy summary')

  cmd:option('--apicast', 'APIcast directory')
    :convert(directory):default('.')

  cmd:option('--template', 'path to a policy template')
    :convert(directory):default('examples/scaffold/policy')

  cmd:option('--version', 'policy version')
    :default('builtin')

  cmd:flag('-f --force', 'override existing files'):default(false)
  cmd:flag('-n --dry-run', 'do not create anything')
    :default(false)
    :action(function() error('dry run does not work yet') end)

  cmd:action(call)
end
