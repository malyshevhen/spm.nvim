local Validator = require('spm.core.validator')

--- A custom validator that checks if a path points to a readable file.
---@param path string The file path to check.
---@return boolean, string?
local function isFileReadable(path)
  if vim.fn.filereadable(path) == 1 then
    return true
  else
    return false, string.format("file is not readable or does not exist at '%s'", path)
  end
end

---@class spm.Config : spm.Valid
---@field plugins_toml_path string? Path to plugins.toml file (nil will default to config_root/plugins.toml)
---@field lock_file_path string? Path to the lock file
---@field auto_source_configs boolean? Whether to automatically source config files
---@field auto_setup_keymaps boolean? Whether to automatically setup keymap system
---@field show_startup_messages boolean? Whether to show startup messages
---@field debug_mode boolean? Enable debug logging
local Config = {}
Config.__index = Config

---@type spm.Schema.Definition
Config.schema = {
  plugins_toml_path = { type = 'string', optional = true, custom = isFileReadable },
  lock_file_path = { type = 'string', optional = true },
  auto_source_configs = { type = 'boolean' },
  auto_setup_keymaps = { type = 'boolean' },
  show_startup_messages = { type = 'boolean' },
  debug_mode = { type = 'boolean' },
}

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
---@return boolean, string?
function Config:valid() return Validator.validate(self) end

--- Creates a new configuration by merging user config with defaults
---@param user_config table? User-provided configuration
---@return spm.Config?, string?
function Config.create(user_config)
  if user_config and type(user_config) ~= 'table' then
    return nil, 'Configuration must be a table'
  end

  local config = vim.tbl_deep_extend('force', vim.deepcopy(DEFAULT_CONFIG), user_config or {})

  ---@type spm.Config
  config = setmetatable(config, Config)

  -- Final validation of resolved config
  local ok, err = config:valid()
  if not ok then return nil, err end

  return config
end

function Config.default() return vim.deepcopy(DEFAULT_CONFIG) end

return Config
