local Validatable = require('spm.core.validation').Validatable
local logger = require('spm.lib.logger')

---@class spm.PluginSpec: spm.Validatable
---@field name string? Optional human-readable name for the plugin
---@field src string Full URL to the plugin repository (required)
---@field version string? Version or branch to install (defaults to master if not specified)
---@field dependencies string[]? List of dependency plugin URLs
local PluginSpec = {}
PluginSpec.__index = PluginSpec
setmetatable(PluginSpec, { __index = Validatable })

---@type spm.Schema.Definition
PluginSpec.schema = {
  name = { type = 'string', optional = true },
  src = { type = 'string', regex = '^https://' },
  version = { type = 'string', optional = true },
  dependencies = { type = 'table', optional = true },
}

---@param user_config table? User-provided configuration
---@return spm.PluginSpec?, string?
function PluginSpec.create(user_config)
  user_config = user_config or {}
  setmetatable(user_config, PluginSpec)

  -- Final validation of resolved config
  local ok, err = user_config:valid()
  if not ok then return nil, err end

  return user_config
end

---@alias PluginSpecs spm.PluginSpec[]

---@class spm.LanguageServerSpec
---@field servers string[] List of language servers to enable

---@class spm.PluginConfig: spm.Validatable
---@field plugins spm.PluginSpec[] Array of plugin configurations
---@field language_servers spm.LanguageServerSpec? Configuration for language servers
---@field filetypes table? Configuration for filetype mappings
local PluginConfig = {}
PluginConfig.__index = PluginConfig
setmetatable(PluginConfig, { __index = Validatable })

---@type spm.Schema.Definition
PluginConfig.schema = {
  plugins = { type = 'table' },
  language_servers = { type = 'table', optional = true },
  filetypes = { type = 'table', optional = true },
}

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

  setmetatable(config, PluginConfig)

  -- Final validation of resolved config
  local ok, err = config:valid()
  if not ok then return nil, err end

  return config
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
