local logger = require('spm.lib.logger')

---@class spm.PluginSpec
---@field name string? Optional human-readable name for the plugin
---@field src string Full URL to the plugin repository (required)
---@field version string? Version or branch to install (defaults to master if not specified)
---@field dependencies string[]? List of dependency plugin URLs
local PluginSpec = {}
PluginSpec.__index = PluginSpec

---@param user_config table? User-provided configuration
---@return spm.PluginSpec?, string?
function PluginSpec.create(user_config)
  if user_config and type(user_config) ~= 'table' then
    return nil, 'Configuration must be a table'
  end

  ---@type spm.PluginSpec
  local plugin_spec = setmetatable(user_config or {}, PluginSpec)

  -- Final validation of resolved config
  local ok, err = plugin_spec:valid()
  if not ok then return nil, err end

  return plugin_spec
end

---Validates a single plugin specification
---@return boolean?, string?
function PluginSpec:valid()
  if type(self) ~= 'table' then return false, 'Plugin must be a table' end

  if not self.src or type(self.src) ~= 'string' or not self.src:match('^https://') then
    return false, "Plugin must have a 'src' field with a valid HTTPS URL"
  end

  return true
end

---@alias PluginSpecs spm.PluginSpec[]

---@class spm.LanguageServerSpec
---@field servers string[] List of language servers to enable

---@class spm.PluginConfig
---@field plugins spm.PluginSpec[] Array of plugin configurations
---@field language_servers spm.LanguageServerSpec? Configuration for language servers
---@field filetypes table? Configuration for filetype mappings
local PluginConfig = {}
PluginConfig.__index = PluginConfig

---@param user_config table? User-provided configuration
---@return spm.PluginConfig?, string?
function PluginConfig.create(user_config)
  if user_config and type(user_config) ~= 'table' then
    return nil, 'Configuration must be a table'
  end

  local config = user_config or {}

  if config.plugins then
    local new_plugins = {}
    for _, plugin in ipairs(config.plugins) do
      if type(plugin) == 'table' then
        local plugin_spec, err = PluginSpec.create(plugin)
        if plugin_spec then
          table.insert(new_plugins, plugin_spec)
        else
          logger.error(err or 'PluginSpec.create failed', 'PluginTypes')
        end
      end
    end
    config.plugins = new_plugins
  end

  ---@type spm.PluginConfig
  local plugin_config = setmetatable(config, PluginConfig)

  -- Final validation of resolved config
  local ok, err = plugin_config:valid()
  if not ok then return nil, err end

  return plugin_config
end

---Validates a complete plugin configuration
---@return boolean?, string?
function PluginConfig:valid()
  if type(self) ~= 'table' then return false, 'Config must be a table' end

  if not self.plugins or type(self.plugins) ~= 'table' then
    return false, "Config must have a 'plugins' field of type array"
  end

  for i, plugin in ipairs(self.plugins) do
    if not plugin.valid then
      return false, string.format('Plugin at index %d: invalid plugin', i)
    end

    local ok, err = plugin:valid()
    if not ok then return false, string.format('Plugin at index %d: %s', i, err) end
  end

  return true
end

---Extracts the repository name from a Git URL
---@param url string The repository URL
---@return string repo_name The repository name (e.g., "owner/repo")
local function extract_repo_name(url)
  local repo_name = url:match('https?://[^/]+/(.+)'):gsub('%.git', '')
  return repo_name or url
end

---Creates a flat list of all plugins including dependencies
---@return spm.PluginSpec[] flattened_plugins All plugins including dependencies as individual entries
function PluginConfig:flatten_plugins()
  local flattened = {}
  local seen_urls = {}

  local function add_plugin(plugin)
    if not seen_urls[plugin.src] then
      flattened[#flattened + 1] = plugin
      seen_urls[plugin.src] = true

      if plugin.dependencies then
        for _, dep_url in ipairs(plugin.dependencies) do
          add_plugin({ src = dep_url, name = extract_repo_name(dep_url) })
        end
      end
    end
  end

  for _, plugin in ipairs(self.plugins) do
    add_plugin(plugin)
  end

  return flattened
end

return { PluginConfig = PluginConfig, PluginSpec = PluginSpec }
