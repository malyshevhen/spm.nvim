local logger = require('spm.lib.logger')

---@class SimplePM
local spm = {
  config_module = require('spm.core.config'),
  keymap = require('spm.core.keymap').map,
  plugin_manager = require('spm.core.plugin_manager'),
}

---Main initialization function
---@param user_config spm.Config? Configuration options
function spm.setup(user_config)
  ---@type spm.Config
  local cfg = user_config or {}

  logger.configure({
    level = cfg.debug_mode and logger.levels.DEBUG or logger.levels.INFO,
    show_notifications = cfg.show_startup_messages or false,
  })

  if cfg.debug_mode then logger.info('Debug mode enabled', 'SimplePM') end

  logger.debug('Initialize config', 'SimplePM')
  local valid_cfg, cfg_err = spm.config_module.create(cfg)
  if cfg_err or not valid_cfg then error(cfg_err or 'Configuration failed to validate') end

  logger.debug('Setup SimplePM', 'SimplePM')
  local pm_ok, pm_err = spm.plugin_manager.setup(valid_cfg)
  if not pm_ok then error(pm_err) end

  logger.info('Initialization complete', 'SimplePM')
end

---Get the keymap compatibility system for direct use
---@param keymaps spm.KeymapSpec[]? Keymaps to map
function spm.keymaps(keymaps) return spm.keymap(keymaps or {}) end

return setmetatable(spm, {
  __newindex = function(_, key, _)
    error(string.format("Cannot modify SimplePM API. Attempted to set '%s'", key))
  end,
  __metatable = 'SimplePM API is protected',
})
