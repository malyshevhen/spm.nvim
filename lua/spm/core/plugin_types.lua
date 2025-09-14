local logger = require('spm.lib.logger')
local Result = require('spm.lib.error').Result

---@class spm.PluginSpec
---@field name string? Optional human-readable name for the plugin
---@field src string Full URL to the plugin repository (required)
---@field version string? Version or branch to install (defaults to master if not specified)
---@field dependencies string[]? List of dependency plugin URLs
local PluginSpec = {}
PluginSpec.__index = PluginSpec

---@param user_config table? User-provided configuration
---@return spm.Result<spm.PluginSpec>
function PluginSpec.create(user_config)
  if user_config and type(user_config) ~= 'table' then
    return Result.err('Configuration must be a table')
  end

  ---@type spm.PluginSpec
  local plugin_spec = setmetatable(user_config or {}, PluginSpec)

  -- Final validation of resolved config
  return plugin_spec:valid()
end

---Validates a single plugin specification
---@return spm.Result<spm.PluginSpec>
function PluginSpec:valid()
  if type(self) ~= 'table' then return Result.err('Plugin must be a table') end

  if not self.src or type(self.src) ~= 'string' or not self.src:match('^https://') then
    return Result.err("Plugin must have a 'src' field with a valid HTTPS URL")
  end

  return Result.ok(self)
end

---@alias PluginList spm.PluginSpec[]

---@class spm.LanguageServerSpec
---@field servers string[] List of language servers to enable

---@class spm.PluginConfig
---@field plugins spm.PluginSpec[] Array of plugin configurations
---@field language_servers spm.LanguageServerSpec? Configuration for language servers
---@field filetypes table? Configuration for filetype mappings
local PluginConfig = {}
PluginConfig.__index = PluginConfig

---@param user_config table? User-provided configuration
---@return spm.Result<spm.PluginConfig>
function PluginConfig.create(user_config)
  if user_config and type(user_config) ~= 'table' then
    return Result.err('Configuration must be a table')
  end

  local config = user_config or {}

  if config.plugins then
    config.plugins = vim.tbl_map(function(plugin)
      if type(plugin) == 'table' then
        local plugin_spec_result = PluginSpec.create(plugin)
        if plugin_spec_result:is_ok() then return plugin_spec_result:unwrap() end

        logger.error(plugin_spec_result.error.message, 'PluginTypes')
      end
    end, config.plugins)
  end

  ---@type spm.PluginConfig
  local plugin_config = setmetatable(config, PluginConfig)

  -- Final validation of resolved config
  return plugin_config:valid()
end

---Validates a complete plugin configuration
---@return spm.Result<spm.PluginConfig>
function PluginConfig:valid()
  if type(self) ~= 'table' then return Result.err('Config must be a table') end

  if not self.plugins or type(self.plugins) ~= 'table' then
    return Result.err("Config must have a 'plugins' field of type array")
  end

  for i, plugin in ipairs(self.plugins) do
    setmetatable(plugin, PluginSpec)
    local validation_result = plugin:valid()
    if validation_result:is_err() then
      return Result.err(string.format('Plugin at index %d: %s', i, validation_result.error.message))
    end
  end

  return Result.ok(self)
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
