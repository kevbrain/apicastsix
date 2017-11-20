--- APIcast source loader
-- Loading this module will add a new source code loader to package.searchers.
-- The searcher is going to print deprecation warnings when apicast source is loaded
-- through old or non prefixed paths.
-- We can rename files and set up an alias here so we don't break customer's code and
-- print a deprecation warning.

local loadfile = loadfile

local map = {
  ['apicast'] = 'apicast.policy.apicast'
}

local function loader(name, path)
  local file, err = package.searchpath(name, path)

  if file then
    file, err = loadfile(file)
  end

  return file, err
end

local function prefix_loader(name, path)
  local prefixed = 'apicast.' .. name
  local found, err = loader(prefixed, path)

  if found then
    ngx.log(ngx.STDERR, 'DEPRECATION: when loading apicast code use correct prefix: require("', prefixed, '")')
  end

  return found or err
end

local function rename_loader(name, path)
  local new = map[name]
  local found, err = loader(new, path)

  if found then
    ngx.log(ngx.WARN, 'DEPRECATION: file renamed - change: require("', name, '")' ,' to: require("', new, '")')
  end

  return found or err
end

local function apicast_namespace(name)
  local path = package.path

  if not package.searchpath(name, path) then
    if map[name] then
      return rename_loader(name, path)
    else
      return prefix_loader(name, path)
    end
  end
end

table.insert(package.searchers, apicast_namespace)
