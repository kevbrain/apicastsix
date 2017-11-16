local setmetatable = setmetatable
local pairs = pairs
local min = math.min
local max = math.max
local insert = table.insert
local concat = table.concat

local exec = require('resty.execvp')
local resty_env = require('resty.env')

local Template = require('apicast.template')
local configuration = require('apicast.configuration')

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

local function pick_openesty(candidates)
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

local function nginx_config(context, dir, path, env)
    update_env(env)

    local template = Template:new(context, dir, true)
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

function mt:__call(options)
    local openresty = resty_env.value('APICAST_OPENRESTY_BINARY') or
                      resty_env.value('TEST_NGINX_BINARY') or
                      pick_openesty(self.openresty)
    local dir = resty_env.get('APICAST_DIR') or pl.path.abspath('.')
    local config = configuration.new(dir)
    local path = options.template
    local environment = options.dev and 'development' or options.environment
    local context = config:load(environment)
    local env = {
        APICAST_CONFIGURATION = options.configuration,
        APICAST_CONFIGURATION_LOADER = options.boot and 'boot' or 'lazy',
        APICAST_CONFIGURATION_CACHE = options.cache,
        THREESCALE_DEPLOYMENT_ENV = environment,
    }

    context.worker_processes = options.workers or context.worker_processes

    if options.daemon then
        context.daemon = 'on'
    end


    if options.master and options.master[1] == 'off' then
        context.master_process = 'off'
    end

    context.prefix = dir
    context.ca_bundle = pl.path.abspath(context.ca_bundle or pl.path.join(dir, 'conf', 'ca-bundle.crt'))

    -- also use env from the config file
    update_env(config.env or {})

    local nginx = nginx_config(context, dir, path, env)

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

local function configure(cmd)
    cmd:usage("Usage: apicast-cli start [OPTIONS]")
    cmd:option("--template", "Nginx config template.", 'conf/nginx.conf.liquid')

    cmd:mutex(
        cmd:option('-e --environment', "Deployment to start.", resty_env.get('THREESCALE_DEPLOYMENT_ENV')),
        cmd:flag('--dev', 'Start in development environment')
    )

    cmd:flag("-m --master", "Test the nginx config"):args('?')
    cmd:flag("-t --test", "Test the nginx config")
    cmd:flag("--debug", "Debug mode. Prints more information.")
    cmd:option("-c --configuration",
        "Path to custom config file (JSON)",
        resty_env.get('APICAST_CONFIGURATION'))
    cmd:flag("-d --daemon", "Daemonize.")
    cmd:option("-w --workers",
        "Number of worker processes to start.",
        resty_env.get('APICAST_WORKERS') or 1)
    cmd:option("-p --pid", "Path to the PID file.")
    cmd:mutex(
        cmd:flag('-b --boot',
            "Load configuration on boot.",
            resty_env.get('APICAST_CONFIGURATION_LOADER') == 'boot'),
        cmd:flag('-l --lazy',
            "Load configuration on demand.",
            resty_env.get('APICAST_CONFIGURATION_LOADER') == 'lazy')
    )
    cmd:option("-i --refresh-interval",
        "Cache configuration for N seconds. Using 0 will reload on every request (not for production).",
        resty_env.get('APICAST_CONFIGURATION_CACHE'))

    cmd:mutex(
        cmd:flag('-v --verbose',
            "Increase logging verbosity (can be repeated).")
        :count(("0-%s"):format(#(_M.log_levels) - _M.log_level)),
        cmd:flag('-q --quiet', "Decrease logging verbosity.")
        :count(("0-%s"):format(_M.log_level - 1))
    )
    cmd:option('--log-level', 'Set log level', resty_env.get('APICAST_LOG_LEVEL') or 'warn')
    cmd:option('--log-file', 'Set log file', resty_env.get('APICAST_LOG_FILE') or 'stderr')

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
