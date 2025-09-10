local Result = require('spm.error').Result

---@class SimplePMConfig
---@field plugins_toml_path string? Path to plugins.toml file (nil will default to config_root/plugins.toml)
---@field lock_file_path string? Path to the lock file
---@field auto_source_configs boolean Whether to automatically source config files
---@field auto_setup_keymaps boolean Whether to automatically setup keymap system
---@field show_startup_messages boolean Whether to show startup messages
---@field debug_mode boolean Enable debug logging
---@field config_root string Root directory of the neovim config
local SimplePMConfig = {}
SimplePMConfig.__index = SimplePMConfig

--- Default configuration values
---@type SimplePMConfig
local DEFAULT_CONFIG = {
  plugins_toml_path = nil, -- Will be set to config_root/plugins.toml if nil
  lock_file_path = vim.fn.stdpath('data') .. '/spm.lock',
  auto_source_configs = true,
  auto_setup_keymaps = true,
  show_startup_messages = false,
  debug_mode = false,
  config_root = vim.fn.stdpath('config'),
}

--- Validates the configuration
---@return Result<SimplePMConfig>
function SimplePMConfig:validate()
  if type(self) ~= 'table' then
    return Result.err('Configuration must be a table')
  end

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

  if type(self.debug_mode) ~= 'boolean' then
    return Result.err('debug_mode must be a boolean')
  end

  if type(self.config_root) ~= 'string' then
    return Result.err('config_root must be a string')
  end

  if vim.fn.isdirectory(self.config_root) == 0 then
    return Result.err('config_root must be a valid directory')
  end

  return Result.ok(self)
end

--- Creates a new configuration by merging user config with defaults
---@param user_config table? User-provided configuration
---@return Result<SimplePMConfig>
function SimplePMConfig.create(user_config)
  local config = vim.tbl_deep_extend('force', vim.deepcopy(DEFAULT_CONFIG), user_config or {})

  -- Set default plugins.toml path if not provided
  if not config.plugins_toml_path then
    config.plugins_toml_path = config.config_root .. '/plugins.toml'
  end

  if not config.lock_file_path then
    config.lock_file_path = vim.fn.stdpath('data') .. '/spm.lock'
  end

  setmetatable(config, SimplePMConfig)

  -- Final validation of resolved config
  return config:validate():map(function() return config end)
end

function SimplePMConfig.default()
  return vim.deepcopy(DEFAULT_CONFIG)
end

---Validates that required files exist for the configuration
---@return Result<SimplePMConfig>
function SimplePMConfig:validate_files_exists()
  -- Check if plugins.toml exists
  if vim.fn.filereadable(self.plugins_toml_path) == 0 then
    return Result.err(string.format('plugins.toml not found at: %s', self.plugins_toml_path))
  end

  -- Check if config root is accessible
  if vim.fn.isdirectory(self.config_root) == 0 then
    return Result.err(string.format('Config root directory not found: %s', self.config_root))
  end

  return Result.ok(self)
end

return SimplePMConfig
