--- Environment configuration
-- @module environment
-- This module is providing a configuration to APIcast before and during its initialization.
-- You can load several configuration files.
-- Fields from the ones added later override fields from the previous configurations.
local pl_path = require('pl.path')
local resty_env = require('resty.env')
local linked_list = require('apicast.linked_list')
local setmetatable = setmetatable
local loadfile = loadfile
local pcall = pcall
local require = require
local assert = assert
local error = error
local print = print
local pairs = pairs
local insert = table.insert
local concat = table.concat
local re = require('ngx.re')

local _M = {}
---
-- @field default_environment Default environment name.
-- @table self
_M.default_environment = 'production'

--- Default configuration.
-- @tfield ?string ca_bundle path to CA store file
-- @table environment.default_config default configuration
_M.default_config = {
    ca_bundle = resty_env.value('SSL_CERT_FILE'),
}

local mt = { __index = _M }

--- Load an environment from files in ENV.
-- @treturn Environment
function _M.load()
    local value = resty_env.value('APICAST_LOADED_ENVIRONMENTS')
    local env = _M.new()

    if not value then
        return env
    end

    local environments = re.split(value, '\\|', 'jo')

    for i=1,#environments do
        assert(env:add(environments[i]))
    end

    return env
end

--- Initialize new environment.
-- @treturn Environment
function _M.new()
    return setmetatable({ _context = linked_list.readonly(_M.default_config), loaded = {} }, mt)
end

local function expand_environment_name(name)
    local root = resty_env.value('APICAST_DIR') or pl_path.abspath('.')
    local pwd = resty_env.value('PWD')

    local path = pl_path.abspath(name, pwd)
    local exists = pl_path.isfile(path)

    if exists then
        return nil, path
    end

    path = pl_path.join(root, 'config', ("%s.lua"):format(name))
    exists = pl_path.isfile(path)

    if exists then
        return name, path
    end
end

---------------------
--- @type Environment
-- An instance of @{environment} configuration.

--- Add an environment name or configuration file.
-- @tparam string env environment name or path to a file
function _M:add(env)
    local name, path = expand_environment_name(env)

    if self.loaded[path] then
        return true, 'already loaded'
    end

    if name and path then
        self.name = name
        print('loading ', name ,' environment configuration: ', path)
    elseif path then
        print('loading environment configuration: ', path)
    else
        return nil, 'no configuration found'
    end

    local config = loadfile(path, 't', {
        print = print, inspect = require('inspect'), context = self._context,
        pcall = pcall, require = require, assert = assert, error = error,
    })

    if not config then
        return nil, 'invalid config'
    end

    self.loaded[path] = true

    self._context = linked_list.readonly(config(), self._context)

    return true
end

--- Read/write context
-- @treturn table context with all loaded environments combined
function _M:context()
    return linked_list.readwrite({ }, self._context)
end

--- Store loaded environment file names into ENV.
function _M:save()
    local environments = {}

    for file,_ in pairs(self.loaded) do
        insert(environments, file)
    end

    resty_env.set('APICAST_LOADED_ENVIRONMENTS', concat(environments, '|'))
end

return _M
