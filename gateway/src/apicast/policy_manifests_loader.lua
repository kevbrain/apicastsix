--- Policy manifests loader
-- Finds the manifests for the builtin policies and the other ones loaded.

local pl_file = require('pl.file')
local pl_dir = require('pl.dir')
local pl_path = require('pl.path')
local cjson = require('cjson')
local format = string.format
local ipairs = ipairs
local insert = table.insert
local policy_loader = require('apicast.policy_loader')

local _M = {}

local builtin_policy_load_path = policy_loader.builtin_policy_load_path
local policy_load_paths = policy_loader.policy_load_paths

local policy_manifest_name = 'apicast-policy.json'

local function dir_iter(dir)
  return ipairs(pl_dir.getdirectories(dir))
end

-- Returns the manifests for all the built-in policies.
local function all_builtin_policy_manifests()
  local manifests = {}

  for _, policy_dir in dir_iter(builtin_policy_load_path()) do
    local manifest_file = format('%s/%s', policy_dir, policy_manifest_name)
    local manifest = pl_file.read(manifest_file)
    if manifest then insert(manifests, cjson.decode(manifest)) end
  end

  return manifests
end

-- Returns a manifest from a 'version' directory. Policies that are not
-- built-in, are located in a path like policies/my_policy/1.0.0.
-- This function tries to fetch a manifest starting from that `1.0.0` directory.
-- It looks for the json manifest, gets its version, and compares it against the
-- version in the directory.
-- Returns the manifest when found. When it's not present or there's a version
-- mismatch, it returns nil.
local function get_manifest_from_version_dir(version_dir)
  local manifest_file = format('%s/%s', version_dir, policy_manifest_name)
  local manifest = pl_file.read(manifest_file)

  if manifest then
    local decoded_manifest = cjson.decode(manifest)
    local version_in_manifest = decoded_manifest.version
    local version_in_path = pl_path.basename(version_dir)

    if version_in_path == version_in_manifest then
      return decoded_manifest
    else
      ngx.log(ngx.WARN,
        'Could not load ', decoded_manifest.name,
        ' version in manifest is ', version_in_manifest,
        ' but version in path is ', version_in_path)
    end
  end
end

-- Returns all the non-built-in manifests from the paths specified by the user.
-- These paths always follow the same pattern. It contains a directory for each
-- policy, and each of those contain a directory for each version of that
-- policy. The json manifest is in that 'version' directory.
local function all_loaded_policy_manifests()
  local manifests = {}

  for _, load_path in ipairs(policy_load_paths()) do
    if pl_path.exists(load_path) then
      for _, policy_dir in dir_iter(load_path) do
        for _, version_dir in dir_iter(policy_dir) do
          local manifest = get_manifest_from_version_dir(version_dir)
          if manifest then insert(manifests, manifest) end
        end
      end
    end
  end

  return manifests
end

--- Get the manifests for all the policies. Both the builtin policies and the
-- ones present in the directories configured as directories that can
-- include policies.
-- @treturn table Manifests for all the policies.
function _M.get_all()
  local manifests = all_builtin_policy_manifests()

  for _, manifest in ipairs(all_loaded_policy_manifests()) do
    insert(manifests, manifest)
  end

  return manifests
end

return _M
