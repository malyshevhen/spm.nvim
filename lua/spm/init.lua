local logger = require('spm.logger')
local Result = require('spm.error').Result

---@class SimplePM
local spm = {
  config_module = require('spm.config'),
  keymap = require('spm.keymap'),
  plugin_manager = require('spm.plugin_manager'),
}

---Sets up logging based on configuration
---@param config spm.Config
---@return spm.Config
local function setup_logging(config) return config end

---Main initialization function
---@param user_config spm.Config? Configuration options
function spm.setup(user_config)
  ---@type spm.Config
  local cfg = user_config or {}

  logger.configure({
    level = cfg.debug_mode and logger.levels.DEBUG or logger.levels.INFO,
    show_notifications = cfg.show_startup_messages or false,
  })

  if cfg.debug_mode then
    logger.info('Debug mode enabled', 'SimplePM')
  end

  logger.debug('Initialize config', 'SimplePM')
  cfg = spm.config_module.create(cfg):unwrap()

  logger.debug('Check required config files', 'SimplePM')
  spm.config_module.validate_files_exists(cfg):unwrap()

  logger.debug('Setup SimplePM', 'SimplePM')
  spm.plugin_manager.setup(cfg):unwrap()

  logger.info('Initialization complete', 'SimplePM')
end

---Get the keymap compatibility system for direct use
---@param keymaps spm.KeymapSpec[]? Keymaps to map
function spm.keymaps(keymaps) spm.keymap.map(keymaps or {}) end

return setmetatable(spm, {
  __newindex = function(_, key, _)
    error(string.format("Cannot modify SimplePM API. Attempted to set '%s'", key))
  end,
  __metatable = 'SimplePM API is protected',
})
