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
---@return Result<nil>
function spm.init(user_config)
  return spm.config_module.SimplePMConfig.create(user_config)
      :flat_map(function(config)
        setup_logging(config)
        return config:validate_files_exists()
            :flat_map(function()
              return spm.plugin_manager.setup(config)
            end)
      end)
      :map(function()
        logger.info('Initialization complete', 'SimplePM')
        return nil
      end)
      :or_else(function(err)
        logger.error('Initialization failed: ' .. err.message, 'SimplePM')
        return Result.err(err)
      end)
end

---Quick setup function with minimal configuration
---@param plugins_toml_path string? Path to plugins.toml file
---@return Result<nil>
function spm.setup(plugins_toml_path)
  return spm.init({ plugins_toml_path = plugins_toml_path })
end

---Get the keymap compatibility system for direct use
---@param keymaps KeymapSpec[]? Keymaps to map
function spm.keymaps(keymaps)
  spm.keymap.map(keymaps or {})
end

return setmetatable(spm, {
  __newindex = function(_, key, _)
    error(string.format("Cannot modify SimplePM API. Attempted to set '%s'", key))
  end,
  __metatable = 'SimplePM API is protected',
})
