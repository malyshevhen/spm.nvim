---@class PluginSpec
---@field name string? Optional human-readable name for the plugin
---@field src string Full URL to the plugin repository (required)
---@field version string? Version or branch to install (defaults to master if not specified)
---@field dependencies string[]? List of dependency plugin URLs
local PluginSpec = {}
PluginSpec.__index = PluginSpec

---Validates a single plugin specification
---@return boolean valid True if the plugin spec is valid
---@return string? error_msg Error message if validation fails
function PluginSpec:validate()
  if type(self) ~= 'table' then
    return false, 'Plugin must be a table'
  end

  if not self.src or type(self.src) ~= 'string' then
    return false, "Plugin must have a 'src' field of type string"
  end

  if not self.src:match('^https://') then
    return false, "Plugin 'src' must be an HTTPS URL"
  end

  if self.name and type(self.name) ~= 'string' then
    return false, "Plugin 'name' must be a string"
  end

  if self.version and type(self.version) ~= 'string' then
    return false, "Plugin 'version' must be a string"
  end

  if self.dependencies then
    if type(self.dependencies) ~= 'table' then
      return false, "Plugin 'dependencies' must be an array"
    end

    for i, dep in ipairs(self.dependencies) do
      if type(dep) ~= 'string' then
        return false, string.format('Dependency at index %d must be a string', i)
      end

      if not dep:match('^https://') then
        return false, string.format('Dependency at index %d must be an HTTPS URL', i)
      end
    end
  end

  return true, nil
end

---@class LanguageServerSpec
---@field servers string[] List of language servers to enable

---@class PluginConfig
---@field plugins PluginSpec[] Array of plugin configurations
---@field language_servers LanguageServerSpec? Configuration for language servers
---@field filetypes table? Configuration for filetype mappings
local PluginConfig = {}
PluginConfig.__index = PluginConfig

---@alias PluginList PluginSpec[]

---Validates a complete plugin configuration
---@return boolean valid True if the config is valid
---@return string? error_msg Error message if validation fails
function PluginConfig:validate()
  if type(self) ~= 'table' then
    return false, 'Config must be a table'
  end

  if not self.plugins or type(self.plugins) ~= 'table' then
    return false, "Config must have a 'plugins' field of type array"
  end

  for i, plugin in ipairs(self.plugins) do
    local valid, err = plugin:validate()
    if not valid then
      return false, string.format('Plugin at index %d: %s', i, err)
    end
  end

  if self.language_servers then
    if type(self.language_servers) ~= 'table' then
      return false, "'language_servers' must be a table"
    end
    if self.language_servers.servers and type(self.language_servers.servers) ~= 'table' then
      return false, "'language_servers.servers' must be an array"
    end
    if self.language_servers.servers then
      for i, server in ipairs(self.language_servers.servers) do
        if type(server) ~= 'string' then
          return false, string.format('Server at index %d must be a string', i)
        end

        if not server:match('^https://') then
          return false, string.format('Server at index %d must be an HTTPS URL', i)
        end
      end
    end
  end

  if self.filetypes then
    if type(self.filetypes) ~= 'table' then
      return false, "'filetypes' must be a table"
    end
    if self.filetypes.pattern and type(self.filetypes.pattern) ~= 'table' then
      return false, "'filetypes.pattern' must be a table"
    end
  end

  return true, nil
end

---Extracts the repository name from a GitHub URL
---@param url string The repository URL
---@return string repo_name The repository name (e.g., "owner/repo")
local function extract_repo_name(url)
  local repo_name = url:match('https://github%.com/(.+)')
  repo_name = repo_name or url:match('https://gitlab%.com/(.+)')

  if repo_name then
    -- Remove .git suffix if present
    repo_name = repo_name:gsub('%.git$', '')
    return repo_name
  end

  -- For non-GitHub URLs, try to extract a reasonable name
  local path = url:match('https://[^/]+/(.+)')
  if path then
    path = path:gsub('%.git$', '')
    return path
  end

  -- Fallback: use the last part of the URL
  return url:match('/([^/]+)/?$') or url
end

---Creates a flat list of all plugins including dependencies
---@param config PluginConfig The plugin configuration
---@return PluginSpec[] flattened_plugins All plugins including dependencies as individual entries
local function flatten_plugins(config)
  local flattened = {}
  local seen_urls = {}

  for _, plugin in ipairs(config.plugins) do
    -- Add the main plugin
    if not seen_urls[plugin.src] then
      flattened[#flattened + 1] = plugin
      seen_urls[plugin.src] = true
    end

    -- Add dependencies as individual plugins
    if plugin.dependencies then
      for _, dep_url in ipairs(plugin.dependencies) do
        if not seen_urls[dep_url] then
          local dep_plugin = {
            src = dep_url,
            name = extract_repo_name(dep_url),
          }
          flattened[#flattened + 1] = dep_plugin
          seen_urls[dep_url] = true
        end
      end
    end
  end

  return flattened
end

return {
  flatten_plugins = flatten_plugins,
}
