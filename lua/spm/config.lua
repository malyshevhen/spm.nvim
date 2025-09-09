---@class SimplePMConfig
---@field plugins_toml_path string? Path to plugins.toml file (nil will default to config_root/plugins.toml)
---@field lock_file_path string? Path to the lock file
---@field auto_source_configs boolean Whether to automatically source config files
---@field auto_setup_keymaps boolean Whether to automatically setup keymap system
---@field show_startup_messages boolean Whether to show startup messages
---@field debug_mode boolean Enable debug logging
---@field config_root string Root directory of the neovim config

---@class ConfigModule
local M = {}

--- Default configuration values
---@type SimplePMConfig
local DEFAULT_CONFIG = {
  plugins_toml_path = nil, -- Will be set to config_root/plugins.toml if nil
  lock_file_path = vim.fn.stdpath 'data' .. '/simple_pm.lock',
  auto_source_configs = true,
  auto_setup_keymaps = true,
  show_startup_messages = false,
  debug_mode = false,
  config_root = vim.fn.stdpath 'config',
}

---Simple validation for configuration object
---@param config table The configuration to validate
---@return boolean valid True if the config is valid
---@return string? error_msg Error message if validation fails
local function validate_config(config)
  if type(config) ~= 'table' then
    return false, 'Configuration must be a table'
  end

  -- Validate required fields and types
  if config.plugins_toml_path ~= nil and type(config.plugins_toml_path) ~= 'string' then
    return false, 'plugins_toml_path must be a string or nil'
  end

  if config.lock_file_path ~= nil and type(config.lock_file_path) ~= 'string' then
    return false, 'lock_file_path must be a string or nil'
  end

  if type(config.auto_source_configs) ~= 'boolean' then
    return false, 'auto_source_configs must be a boolean'
  end

  if type(config.auto_setup_keymaps) ~= 'boolean' then
    return false, 'auto_setup_keymaps must be a boolean'
  end

  if type(config.show_startup_messages) ~= 'boolean' then
    return false, 'show_startup_messages must be a boolean'
  end

  if type(config.debug_mode) ~= 'boolean' then
    return false, 'debug_mode must be a boolean'
  end

  if type(config.config_root) ~= 'string' then
    return false, 'config_root must be a string'
  end

  if vim.fn.isdirectory(config.config_root) == 0 then
    return false, 'config_root must be a valid directory'
  end

  return true, nil
end

---Resolves configuration paths and sets defaults
---@param config SimplePMConfig The configuration to resolve
---@return SimplePMConfig resolved_config The resolved configuration
local function resolve_config(config)
  local resolved = vim.deepcopy(config)

  -- Set default plugins.toml path if not provided
  if not resolved.plugins_toml_path then
    resolved.plugins_toml_path = resolved.config_root .. '/plugins.toml'
  end

  if not resolved.lock_file_path then
    resolved.lock_file_path = vim.fn.stdpath 'data' .. '/simple_pm.lock'
  end

  return resolved
end

---Creates a new configuration by merging user config with defaults
---@param user_config table? User-provided configuration
---@return SimplePMConfig? config The final configuration
---@return string? error Error message if validation fails
function M.create(user_config)
  user_config = user_config or {}

  -- Merge with defaults first
  local merged = vim.tbl_deep_extend('force', DEFAULT_CONFIG, user_config)

  -- Resolve paths and dependencies
  local resolved = resolve_config(merged)

  -- Final validation of resolved config
  local valid, err = validate_config(resolved)
  if not valid then
    return nil, err
  end

  return resolved, nil
end

---Validates that required files exist for the configuration
---@param config SimplePMConfig The configuration to validate
---@return boolean valid True if all required files exist
---@return string? error_msg Error message if validation fails
function M.validate_files_exists(config)
  -- Check if plugins.toml exists
  if vim.fn.filereadable(config.plugins_toml_path) == 0 then
    return false, string.format('plugins.toml not found at: %s', config.plugins_toml_path)
  end

  -- Check if config root is accessible
  if vim.fn.isdirectory(config.config_root) == 0 then
    return false, string.format('Config root directory not found: %s', config.config_root)
  end

  return true, nil
end

---Creates a debug-enabled configuration
---@param user_config table? User-provided configuration
---@return SimplePMConfig? config The debug configuration
---@return string? error Error message if validation fails
function M.create_debug(user_config)
  local config = vim.tbl_deep_extend('force', user_config or {}, { debug_mode = true })
  return M.create(config)
end

---Creates a minimal configuration with only essential settings
---@param plugins_toml_path string? Path to plugins.toml file
---@return SimplePMConfig? config The minimal configuration
---@return string? error Error message if validation fails
function M.create_minimal(plugins_toml_path)
  return M.create {
    plugins_toml_path = plugins_toml_path,
    debug_mode = false,
    auto_source_configs = true,
    auto_setup_keymaps = true,
  }
end

---Gets the default configuration (for reference/documentation)
---@return SimplePMConfig default_config The default configuration
function M.get_defaults()
  return vim.deepcopy(DEFAULT_CONFIG)
end

return M

