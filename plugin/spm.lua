local config_module = require('spm.config')
local logger = require('spm.logger')
local keymap = require('spm.keymap')

---@class SimplePM
local SimplePM = {}

---Sets up logging based on configuration
---@param config SimplePMConfig
local function setup_logging(config)
  logger.configure({
    level = config.debug_mode and logger.levels.DEBUG or logger.levels.INFO,
    show_notifications = config.show_startup_messages,
  })
  if config.debug_mode then
    logger.info('Debug mode enabled', 'SimplePM')
  end
end

---Main initialization function
---@param user_config table? Configuration options
---@return boolean success True if initialization was successful
function SimplePM.init(user_config)
  -- Create and validate configuration
  local config, config_error = config_module.create(user_config)
  if not config then
    -- Use logger directly since it might not be configured yet
    logger.error('Configuration error: ' .. (config_error or 'Unknown error'), 'SimplePM')
    return false
  end

  setup_logging(config)

  -- Validate required files exist
  local files_valid, file_error = config_module.validate_files_exists(config)
  if not files_valid then
    logger.error('File validation error: ' .. (file_error or 'Unknown error'), 'SimplePM')
    return false
  end

  logger.info('Initialization complete', 'SimplePM')
  return true
end

---Quick setup function with minimal configuration
---@param plugins_toml_path string? Path to plugins.toml file
---@return boolean success True if setup was successful
function SimplePM.setup(plugins_toml_path)
  local config, config_error = config_module.create_minimal(plugins_toml_path)
  if not config then
    logger.error('Setup configuration error: ' .. (config_error or 'Unknown error'), 'SimplePM')
    return false
  end
  return SimplePM.init(config)
end

---Get the keymap compatibility system for direct use
---@param keymaps KeymapSpec[]? Keymaps to map
function SimplePM.keymaps(keymaps)
  keymap.map(keymaps or {})
end

return SimplePM
