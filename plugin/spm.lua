local config_module = require('spm.config')
local logger = require('spm.logger')
local keymap = require('spm.keymap')
local plugin_manager = require('spm.plugin_manager')

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
  local config, config_error = config_module.SimplePMConfig.create(user_config)
  if not config then
    logger.error('Configuration error: ' .. (config_error or 'Unknown error'), 'SimplePM')
    return false
  end

  setup_logging(config)

  local files_valid, file_error = config:validate_files_exists()
  if not files_valid then
    logger.error('File validation error: ' .. (file_error or 'Unknown error'), 'SimplePM')
    return false
  end

  local success, setup_error = plugin_manager.setup(config)
  if not success then
    logger.error('Plugin setup failed: ' .. (setup_error or 'Unknown error'), 'SimplePM')
    return false
  end

  logger.info('Initialization complete', 'SimplePM')
  return true
end

---Quick setup function with minimal configuration
---@param plugins_toml_path string? Path to plugins.toml file
---@return boolean success True if setup was successful
function SimplePM.setup(plugins_toml_path)
  return SimplePM.init({ plugins_toml_path = plugins_toml_path })
end

---Get the keymap compatibility system for direct use
---@param keymaps KeymapSpec[]? Keymaps to map
function SimplePM.keymaps(keymaps)
  keymap.map(keymaps or {})
end

return SimplePM
