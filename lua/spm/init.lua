local logger = require('spm.logger')
local Result = require('spm.error').Result

---@class SimplePM
local spm = {
  config_module = require('spm.config'),
  keymap = require('spm.keymap'),
  plugin_manager = require('spm.plugin_manager'),
}

---Sets up logging based on configuration
---@param config SimplePMConfig
---@return SimplePMConfig
local function setup_logging(config)
  logger.configure({
    level = config.debug_mode and logger.levels.DEBUG or logger.levels.INFO,
    show_notifications = config.show_startup_messages,
  })
  if config.debug_mode then logger.info('Debug mode enabled', 'SimplePM') end

  return config
end

---Main initialization function
---@param user_config SimplePMConfig? Configuration options
function spm.setup(user_config)
  local result = spm.config_module
    .create(user_config)
    :map(setup_logging)
    :flat_map(spm.config_module.validate_files_exists)
    :flat_map(spm.plugin_manager.setup)

  if result:is_ok() then
    logger.info('Initialization complete', 'SimplePM')
  else
    logger.error('Initialization failed: ' .. result:unwrap_err().message, 'SimplePM')
  end
end

---Get the keymap compatibility system for direct use
---@param keymaps KeymapSpec[]? Keymaps to map
function spm.keymaps(keymaps) spm.keymap.map(keymaps or {}) end

return setmetatable(spm, {
  __newindex = function(_, key, _)
    error(string.format("Cannot modify SimplePM API. Attempted to set '%s'", key))
  end,
  __metatable = 'SimplePM API is protected',
})
