---@class SimplePM
local M = {}

local config_module = require('spm.config')
local plugin_manager = require('spm.plugin_manager')
local toml_parser = require('spm.toml_parser')
local pack_installer = require('spm.pack_installer')
local file_sourcer = require('spm.file_sourcer')
local keymap_compat = require('spm.keymap_compat')
local logger = require('spm.logger')
local crypto = require('spm.crypto')
local lock_manager_module = require('spm.lock_manager')

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

---Sets up the keymap compatibility layer
---@param config SimplePMConfig
local function setup_keymaps(config)
  if config.auto_setup_keymaps then
    keymap_compat.setup_global()
    logger.debug('Keymap compatibility layer initialized', 'SimplePM')
  end
end

---Creates plugin manager with dependencies
---@return PluginManager
local function create_plugin_manager()
  local dependencies = {
    toml_parser = toml_parser,
    pack_installer = pack_installer,
    file_sourcer = file_sourcer,
    crypto = crypto,
    lock_manager = lock_manager_module.new({
      toml_parser = toml_parser,
      crypto = crypto,
    }),
  }
  return plugin_manager.new(dependencies)
end

---Main initialization function
---@param user_config table? Configuration options
---@return boolean success True if initialization was successful
function M.init(user_config)
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

  setup_keymaps(config)

  -- Create plugin manager and run setup
  local pm = create_plugin_manager()
  local success, error_msg = pm:setup(config)

  if not success then
    logger.error('Plugin manager setup failed: ' .. (error_msg or 'Unknown error'), 'SimplePM')
    return false
  end

  logger.info('Initialization complete', 'SimplePM')
  return true
end

---Quick setup function with minimal configuration
---@param plugins_toml_path string? Path to plugins.toml file
---@return boolean success True if setup was successful
function M.setup(plugins_toml_path)
  local config, config_error = config_module.create_minimal(plugins_toml_path)
  if not config then
    logger.error('Setup configuration error: ' .. (config_error or 'Unknown error'), 'SimplePM')
    return false
  end
  return M.init(config)
end

---Setup with debug mode enabled
---@param plugins_toml_path string? Path to plugins.toml file
---@return boolean success True if setup was successful
function M.setup_debug(plugins_toml_path)
  local config, config_error = config_module.create_debug({ plugins_toml_path = plugins_toml_path })
  if not config then
    logger.error(
      'Debug setup configuration error: ' .. (config_error or 'Unknown error'),
      'SimplePM'
    )
    return false
  end
  return M.init(config)
end

---Get the keymap compatibility system for direct use
---@return table keymap_compat_module The keymap compatibility module
function M.keymap()
  return keymap_compat
end

---Get a plugin manager instance for direct use
---@return PluginManager plugin_manager_instance The plugin manager instance
function M.manager()
  return create_plugin_manager()
end

---Create user commands for debugging and management
local function create_user_commands()
  vim.api.nvim_create_user_command('SimplePMShowLogs', function()
    local history = logger.get_history()
    if #history == 0 then
      print('No SimplePM logs for this session.')
      return
    end
    print('--- SimplePM Log History ---')
    for _, msg in ipairs(history) do
      print(msg)
    end
    print('--- End of Log History ---')
  end, { desc = 'Show the SimplePM log history for the current session.' })

  vim.api.nvim_create_user_command('SimplePMDebugPlugins', function()
    local config_root = vim.fn.stdpath('config')
    local plugins_toml_path = config_root .. '/plugins.toml'
    local pm = create_plugin_manager()
    local plugins, error_msg = pm:debug_plugins(plugins_toml_path)
    if not plugins then
      logger.error('Debug plugins failed: ' .. (error_msg or 'Unknown error'), 'SimplePM')
    end
  end, { desc = 'Show parsed plugins from plugins.toml' })

  vim.api.nvim_create_user_command('SimplePMTestKeymaps', function()
    if keymap_compat.is_active() then
      logger.info('Keymap compatibility system is active', 'SimplePM')
      local K = keymap_compat.get_global()
      if K then
        K:map({
          {
            map = '<leader>test',
            cmd = ':echo "SimplePM test successful!"<CR>',
            desc = 'Test keymap',
          },
        })
        logger.info('Test keymap created successfully', 'SimplePM')
      end
    else
      logger.warn('Keymap compatibility system is not active', 'SimplePM')
    end
  end, { desc = 'Test the keymap compatibility system' })

  vim.api.nvim_create_user_command('SimplePMReinstall', function()
    local config, config_error = config_module.create()
    if not config then
      logger.error(
        'Could not create config for reinstall: ' .. (config_error or 'unknown'),
        'SimplePM'
      )
      return
    end

    local pm = create_plugin_manager()
    local success, error_msg = pm:setup(config, true)
    if success then
      logger.info('Reinstall completed successfully', 'SimplePM')
    else
      logger.error('Reinstall failed: ' .. (error_msg or 'Unknown error'), 'SimplePM')
    end
  end, { desc = 'Reinstall plugins and source configuration' })
end

create_user_commands()

return M
