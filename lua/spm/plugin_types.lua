---@class PluginSpec
---@field name string? Optional human-readable name for the plugin
---@field src string Full URL to the plugin repository (required)
---@field version string? Version or branch to install (defaults to master if not specified)
---@field dependencies string[]? List of dependency plugin URLs

---@class PluginConfig
---@field plugins PluginSpec[] Array of plugin configurations
---@field language_servers table? Configuration for language servers
---@field filetypes table? Configuration for filetype mappings

---@alias PluginList PluginSpec[]

local M = {}

---Validates a single plugin specification
---@param plugin PluginSpec The plugin specification to validate
---@return boolean valid True if the plugin spec is valid
---@return string? error_msg Error message if validation fails
function M.validate_plugin(plugin)
  if type(plugin) ~= 'table' then
    return false, 'Plugin must be a table'
  end

  if not plugin.src or type(plugin.src) ~= 'string' then
    return false, "Plugin must have a 'src' field of type string"
  end

  if not plugin.src:match '^https://' then
    return false, "Plugin 'src' must be an HTTPS URL"
  end

  if plugin.name and type(plugin.name) ~= 'string' then
    return false, "Plugin 'name' must be a string"
  end

  if plugin.version and type(plugin.version) ~= 'string' then
    return false, "Plugin 'version' must be a string"
  end

  if plugin.dependencies then
    if type(plugin.dependencies) ~= 'table' then
      return false, "Plugin 'dependencies' must be an array"
    end

    for i, dep in ipairs(plugin.dependencies) do
      if type(dep) ~= 'string' then
        return false, string.format('Dependency at index %d must be a string', i)
      end

      if not dep:match '^https://' then
        return false, string.format('Dependency at index %d must be an HTTPS URL', i)
      end
    end
  end

  return true, nil
end

---Validates a complete plugin configuration
---@param config PluginConfig The plugin configuration to validate
---@return boolean valid True if the config is valid
---@return string? error_msg Error message if validation fails
function M.validate_config(config)
  if type(config) ~= 'table' then
    return false, 'Config must be a table'
  end

  if not config.plugins or type(config.plugins) ~= 'table' then
    return false, "Config must have a 'plugins' field of type array"
  end

  for i, plugin in ipairs(config.plugins) do
    local valid, err = M.validate_plugin(plugin)
    if not valid then
      return false, string.format('Plugin at index %d: %s', i, err)
    end
  end

  if config.language_servers then
    if type(config.language_servers) ~= 'table' then
      return false, "'language_servers' must be a table"
    end
    if config.language_servers.servers and type(config.language_servers.servers) ~= 'table' then
      return false, "'language_servers.servers' must be an array"
    end
    if config.language_servers.servers then
      for i, server in ipairs(config.language_servers.servers) do
        if type(server) ~= 'string' then
          return false, string.format('Server at index %d must be a string', i)
        end
      end
    end
  end

  if config.filetypes then
    if type(config.filetypes) ~= 'table' then
      return false, "'filetypes' must be a table"
    end
    if config.filetypes.pattern and type(config.filetypes.pattern) ~= 'table' then
      return false, "'filetypes.pattern' must be a table"
    end
  end

  return true, nil
end

---Extracts the repository name from a GitHub URL
---@param url string The repository URL
---@return string repo_name The repository name (e.g., "owner/repo")
function M.extract_repo_name(url)
  local repo_name = url:match 'https://github%.com/(.+)'
  if repo_name then
    -- Remove .git suffix if present
    repo_name = repo_name:gsub('%.git$', '')
    return repo_name
  end

  -- For non-GitHub URLs, try to extract a reasonable name
  local path = url:match 'https://[^/]+/(.+)'
  if path then
    path = path:gsub('%.git$', '')
    return path
  end

  -- Fallback: use the last part of the URL
  return url:match '/([^/]+)/?$' or url
end

---Creates a flat list of all plugins including dependencies
---@param config PluginConfig The plugin configuration
---@return PluginSpec[] flattened_plugins All plugins including dependencies as individual entries
function M.flatten_plugins(config)
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
            name = M.extract_repo_name(dep_url),
          }
          flattened[#flattened + 1] = dep_plugin
          seen_urls[dep_url] = true
        end
      end
    end
  end

  return flattened
end

return M
