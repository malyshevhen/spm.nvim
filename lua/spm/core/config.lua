---@class spm.Config
---@field plugins_toml_path string? Path to plugins.toml file (nil will default to config_root/plugins.toml)
---@field lock_file_path string? Path to the lock file
---@field auto_source_configs boolean? Whether to automatically source config files
---@field auto_setup_keymaps boolean? Whether to automatically setup keymap system
---@field show_startup_messages boolean? Whether to show startup messages
---@field debug_mode boolean? Enable debug logging
local Config = {}
Config.__index = Config

--- Default configuration values
---@type spm.Config
local DEFAULT_CONFIG = {
  plugins_toml_path = vim.fn.stdpath('config') .. '/plugins.toml',
  lock_file_path = vim.fn.stdpath('data') .. '/spm.lock',
  auto_source_configs = true,
  auto_setup_keymaps = true,
  show_startup_messages = false,
  debug_mode = false,
}

--- Validates the configuration
---@return table?, string?
function Config:valid()
  if type(self) ~= 'table' then return nil, 'Configuration must be a table' end

  -- Validate required fields and types
  if self.plugins_toml_path ~= nil and type(self.plugins_toml_path) ~= 'string' then
    return nil, 'plugins_toml_path must be a string or nil'
  end

  if self.lock_file_path ~= nil and type(self.lock_file_path) ~= 'string' then
    return nil, 'lock_file_path must be a string or nil'
  end

  if type(self.auto_source_configs) ~= 'boolean' then
    return nil, 'auto_source_configs must be a boolean'
  end

  if type(self.auto_setup_keymaps) ~= 'boolean' then
    return nil, 'auto_setup_keymaps must be a boolean'
  end

  if type(self.show_startup_messages) ~= 'boolean' then
    return nil, 'show_startup_messages must be a boolean'
  end

  if type(self.debug_mode) ~= 'boolean' then return nil, 'debug_mode must be a boolean' end

  return self
end

--- Creates a new configuration by merging user config with defaults
---@param user_config table? User-provided configuration
---@return table?, string?
function Config.create(user_config)
  if user_config and type(user_config) ~= 'table' then
    return nil, 'Configuration must be a table'
  end

  local config = vim.tbl_deep_extend('force', vim.deepcopy(DEFAULT_CONFIG), user_config or {})

  ---@type spm.Config
  config = setmetatable(config, Config)

  -- Final validation of resolved config
  return config:valid()
end

function Config.default() return vim.deepcopy(DEFAULT_CONFIG) end

---Validates that required files exist for the configuration
---@return boolean?, string?
function Config:validate_files_exists()
  -- Check if plugins.toml exists
  if vim.fn.filereadable(self.plugins_toml_path) == 0 then
    return nil, string.format('plugins.toml not found at: %s', self.plugins_toml_path)
  end

  return true
end

return Config
