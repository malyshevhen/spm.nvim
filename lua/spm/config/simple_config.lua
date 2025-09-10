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

--- Creates a new configuration by merging user config with defaults
---@param user_config table? User-provided configuration
---@return SimplePMConfig? config The final configuration
---@return string? error Error message if validation fails
function SimplePMConfig.create(user_config)
  user_config = user_config or {}

  -- Merge with defaults first
  local merged = vim.tbl_deep_extend('force', DEFAULT_CONFIG, user_config)

  -- Resolve paths and dependencies
  ---@type SimplePMConfig
  local resolved = merged:resolve_config()

  -- Final validation of resolved config
  local valid, err = resolved:validate()
  if not valid then
    return nil, err
  end

  return resolved, nil
end

--- Validates the configuration
---@return boolean valid True if the config is valid
---@return string? error_msg Error message if validation fails
function SimplePMConfig:validate()
  if type(self) ~= 'table' then
    return false, 'Configuration must be a table'
  end

  -- Validate required fields and types
  if self.plugins_toml_path ~= nil and type(self.plugins_toml_path) ~= 'string' then
    return false, 'plugins_toml_path must be a string or nil'
  end

  if self.lock_file_path ~= nil and type(self.lock_file_path) ~= 'string' then
    return false, 'lock_file_path must be a string or nil'
  end

  if type(self.auto_source_configs) ~= 'boolean' then
    return false, 'auto_source_configs must be a boolean'
  end

  if type(self.auto_setup_keymaps) ~= 'boolean' then
    return false, 'auto_setup_keymaps must be a boolean'
  end

  if type(self.show_startup_messages) ~= 'boolean' then
    return false, 'show_startup_messages must be a boolean'
  end

  if type(self.debug_mode) ~= 'boolean' then
    return false, 'debug_mode must be a boolean'
  end

  if type(self.config_root) ~= 'string' then
    return false, 'config_root must be a string'
  end

  if vim.fn.isdirectory(self.config_root) == 0 then
    return false, 'config_root must be a valid directory'
  end

  return true, nil
end

--- Resolves configuration paths and sets defaults
---@return SimplePMConfig resolved_config The resolved configuration
function SimplePMConfig:resolve_config()
  local resolved = vim.deepcopy(self)

  -- Set default plugins.toml path if not provided
  if not resolved.plugins_toml_path then
    resolved.plugins_toml_path = resolved.config_root .. '/plugins.toml'
  end

  if not resolved.lock_file_path then
    resolved.lock_file_path = vim.fn.stdpath('data') .. '/spm.lock'
  end

  return resolved
end

function SimplePMConfig.default()
  return vim.deepcopy(DEFAULT_CONFIG)
end

---Validates that required files exist for the configuration
---@return boolean valid True if all required files exist
---@return string? error_msg Error message if validation fails
function SimplePMConfig:validate_files_exists()
  -- Check if plugins.toml exists
  if vim.fn.filereadable(self.plugins_toml_path) == 0 then
    return false, string.format('plugins.toml not found at: %s', self.plugins_toml_path)
  end

  -- Check if config root is accessible
  if vim.fn.isdirectory(self.config_root) == 0 then
    return false, string.format('Config root directory not found: %s', self.config_root)
  end

  return true, nil
end
