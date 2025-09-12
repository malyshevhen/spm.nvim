local Result = require('spm.lib.error').Result

---@class SimplePMConfig
---@field plugins_toml_path string? Path to plugins.toml file (nil will default to config_root/plugins.toml)
---@field lock_file_path string? Path to the lock file
---@field auto_source_configs boolean? Whether to automatically source config files
---@field auto_setup_keymaps boolean? Whether to automatically setup keymap system
---@field show_startup_messages boolean? Whether to show startup messages
---@field debug_mode boolean? Enable debug logging
local SimplePMConfig = {}
SimplePMConfig.__index = SimplePMConfig

--- Default configuration values
---@type SimplePMConfig
local DEFAULT_CONFIG = {
  plugins_toml_path = vim.fn.stdpath('config') .. '/plugins.toml',
  lock_file_path = vim.fn.stdpath('data') .. '/spm.lock',
  auto_source_configs = true,
  auto_setup_keymaps = true,
  show_startup_messages = false,
  debug_mode = false,
}

--- Validates the configuration
---@return Result<SimplePMConfig>
function SimplePMConfig:validate()
  if type(self) ~= 'table' then return Result.err('Configuration must be a table') end

  -- Validate required fields and types
  if self.plugins_toml_path ~= nil and type(self.plugins_toml_path) ~= 'string' then
    return Result.err('plugins_toml_path must be a string or nil')
  end

  if self.lock_file_path ~= nil and type(self.lock_file_path) ~= 'string' then
    return Result.err('lock_file_path must be a string or nil')
  end

  if type(self.auto_source_configs) ~= 'boolean' then
    return Result.err('auto_source_configs must be a boolean')
  end

  if type(self.auto_setup_keymaps) ~= 'boolean' then
    return Result.err('auto_setup_keymaps must be a boolean')
  end

  if type(self.show_startup_messages) ~= 'boolean' then
    return Result.err('show_startup_messages must be a boolean')
  end

  if type(self.debug_mode) ~= 'boolean' then return Result.err('debug_mode must be a boolean') end

  return Result.ok(self)
end

--- Creates a new configuration by merging user config with defaults
---@param user_config table? User-provided configuration
---@return Result<SimplePMConfig>
function SimplePMConfig.create(user_config)
  if user_config and type(user_config) ~= 'table' then
    return Result.err('Configuration must be a table')
  end

  local config = vim.tbl_deep_extend('force', vim.deepcopy(DEFAULT_CONFIG), user_config or {})

  ---@type SimplePMConfig
  config = setmetatable(config, SimplePMConfig)

  -- Final validation of resolved config
  return config:validate():map(function() return config end)
end

function SimplePMConfig.default() return vim.deepcopy(DEFAULT_CONFIG) end

---Validates that required files exist for the configuration
---@return Result<nil>
function SimplePMConfig:validate_files_exists()
  -- Check if plugins.toml exists
  if vim.fn.filereadable(self.plugins_toml_path) == 0 then
    return Result.err(string.format('plugins.toml not found at: %s', self.plugins_toml_path))
  end

  return Result.ok(nil)
end

return SimplePMConfig
