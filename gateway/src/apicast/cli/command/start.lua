local setmetatable = setmetatable
local pairs = pairs
local min = math.min
local max = math.max
local insert = table.insert
local concat = table.concat
local format = string.format

local exec = require('resty.execvp')
local resty_env = require('resty.env')
local re = require('ngx.re')

local Template = require('apicast.cli.template')
local Environment = require('apicast.cli.environment')

local pl = {
    path = require('pl.path'),
    file = require('pl.file'),
    dir = require('pl.dir'),
}

local _M = {
    openresty = { 'openresty-debug', 'openresty', 'nginx' },
    log_levels = { 'emerg', 'alert', 'crit', 'error', 'warn', 'notice', 'info', 'debug' },
    log_level = 5, -- warn
    log_file = 'stderr',
}

local mt = { __index = _M }

local function find_openresty_command(candidates)
    for i=1, #candidates do
        local ok = os.execute(('%s -V 2>/dev/null'):format(candidates[i]))

        if ok then
            return candidates[i]
        end
    end

    error("could not find openresty executable")
end

local function update_env(env)
    for name, value in pairs(env) do
        resty_env.set(name, value)
    end
end


local function apicast_root()
    return resty_env.value('APICAST_DIR') or pl.path.abspath('.')
end

local function nginx_config(context,path)
    local template = Template:new(context, apicast_root(), true)
    local tmp = pl.path.tmpname()
    pl.file.write(tmp, template:render(path))
    return tmp
end

local function create_prefix()
    local tmp = os.tmpname()

    assert(pl.file.delete(tmp))
    assert(pl.dir.makepath(tmp .. '/logs'))

    return tmp
end

local function get_log_level(self, options)
    local log_level = options.log_level
    local n = #(self.log_levels)
    for i=1, n do
        if self.log_levels[i] == log_level then
            i = i + options.verbose - options.quiet
            log_level = self.log_levels[max(min(i, n), 1)]
            break
        end
    end
    return log_level
end


local function build_environment_config(options)
    local config = Environment.new()

    for i=1, #options.environment do
        local ok, err = config:add(options.environment[i])

        if not ok then
            print('not loading ', options.environment[i], ': ', err)
        end
    end

    if options.dev then config:add('development') end

    config:save()

    return config
end

local function openresty_binary(candidates)
    return resty_env.value('APICAST_OPENRESTY_BINARY') or
        resty_env.value('TEST_NGINX_BINARY') or
        find_openresty_command(candidates)
end

local function build_env(options, config)
    return {
        APICAST_CONFIGURATION = options.configuration,
        APICAST_CONFIGURATION_LOADER = options.boot and 'boot' or 'lazy',
        APICAST_CONFIGURATION_CACHE = options.cache,
        THREESCALE_DEPLOYMENT_ENV = options.channel or config.name,
        APICAST_POLICY_LOAD_PATH = options.policy_load_path,
    }
end

local function build_context(options, config)
    local context = config:context()

    context.worker_processes = options.workers or context.worker_processes

    if options.daemon then
        context.daemon = 'on'
    end

    if options.master and options.master[1] == 'off' then
        context.master_process = 'off'
    end


    context.prefix = apicast_root()
    context.ca_bundle = pl.path.abspath(context.ca_bundle or pl.path.join(context.prefix, 'conf', 'ca-bundle.crt'))

    return context
end

function mt:__call(options)
    local openresty = openresty_binary(self.openresty)
    local config = build_environment_config(options)
    local context = build_context(options, config)
    local env = build_env(options, config)

    local template_path = options.template

    update_env(env)
    -- also use env from the config file
    update_env(context.env or {})

    local nginx = nginx_config(context, template_path)

    local log_level = get_log_level(self, options)
    local log_file = options.log_file or self.log_file
    local global = {
        ('error_log %s %s'):format(log_file, log_level)
    }
    local prefix = create_prefix()

    local cmd = { '-c', nginx, '-g', concat(global, '; ') .. ';', '-p', prefix }

    if options.test then
        insert(cmd, options.debug and '-T' or '-t')
    end

    return exec(openresty, cmd, env)
end

local function split_by(pattern)
  return function(str)
    return re.split(str or '', pattern, 'oj')
  end
end

local load_env = split_by(':')

local function configure(cmd)
    cmd:usage("Usage: apicast-cli start [OPTIONS]")
    cmd:option("--template", "Nginx config template.", 'conf/nginx.conf.liquid')

    local channel = resty_env.value('THREESCALE_DEPLOYMENT_ENV') or 'production'
    local loaded_env = Environment.loaded()

    insert(loaded_env, 1, channel)

    cmd:option('-3 --channel', "3scale configuration channel to use.", channel):action(function(args, name, chan)
      args.environment[1] = chan
      args[name] = chan
    end):count('0-1')
    cmd:option('-e --environment', "Deployment to start. Can also be a path to a Lua file.", resty_env.value('APICAST_ENVIRONMENT'))
      :count('*'):init(loaded_env):action('concat'):convert(load_env)
    cmd:flag('--dev', 'Start in development environment')

    cmd:flag("-m --master", "Test the nginx config"):args('?')
    cmd:flag("-t --test", "Test the nginx config")
    cmd:flag("--debug", "Debug mode. Prints more information.")
    cmd:option("-c --configuration",
        "Path to custom config file (JSON)",
        resty_env.value('APICAST_CONFIGURATION'))
    cmd:flag("-d --daemon", "Daemonize.")
    cmd:option("-w --workers",
        "Number of worker processes to start.",
        resty_env.value('APICAST_WORKERS') or Environment.default_config.worker_processes)
    cmd:option("-p --pid", "Path to the PID file.")
    cmd:mutex(
        cmd:flag('-b --boot',
            "Load configuration on boot.",
            resty_env.value('APICAST_CONFIGURATION_LOADER') == 'boot'),
        cmd:flag('-l --lazy',
            "Load configuration on demand.",
            resty_env.value('APICAST_CONFIGURATION_LOADER') == 'lazy')
    )
    cmd:option("-i --refresh-interval",
        "Cache configuration for N seconds. Using 0 will reload on every request (not for production).",
        resty_env.value('APICAST_CONFIGURATION_CACHE'))

    cmd:option("--policy-load-path",
        "Load path where to find policies. Entries separated by `:`.",
        resty_env.value('APICAST_POLICY_LOAD_PATH') or format('%s/policies', apicast_root())
    )
    cmd:mutex(
        cmd:flag('-v --verbose',
            "Increase logging verbosity (can be repeated).")
        :count(("0-%s"):format(#(_M.log_levels) - _M.log_level)),
        cmd:flag('-q --quiet', "Decrease logging verbosity.")
        :count(("0-%s"):format(_M.log_level - 1))
    )
    cmd:option('--log-level', 'Set log level', resty_env.value('APICAST_LOG_LEVEL') or 'warn')
    cmd:option('--log-file', 'Set log file', resty_env.value('APICAST_LOG_FILE') or 'stderr')

    cmd:epilog([[
      Example: apicast start --dev
        This will start APIcast in development mode.]])

    return cmd
end

function _M.new(parser)
    local cmd = configure(parser:command('start', 'Start APIcast'))

    return setmetatable({ parser = parser, cmd = cmd }, mt)
end

function _M:parse(arg)
    return self.cmd:parse(arg)
end


return setmetatable(_M, mt)
