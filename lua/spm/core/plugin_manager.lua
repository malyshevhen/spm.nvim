local crypto = require('spm.lib.crypto')
local file_sourcer = require('spm.lib.file_sourcer')
local fs = require('spm.lib.fs')
local lock_manager = require('spm.core.lock_manager')
local logger = require('spm.lib.logger')
local plugin_installer = require('spm.core.plugin_installer')
local plugin_types = require('spm.core.plugin_types')
local toml_parser = require('spm.lib.toml_parser')
local PluginConfig = plugin_types.PluginConfig
local Result = require('spm.lib.error').Result

---Parses the plugins configuration file
---@param plugins_toml_path string Path to the plugins.toml file
---@return spm.Result<spm.PluginConfig>
local function parse_config(plugins_toml_path)
  logger.info(string.format('Parsing configuration: %s', plugins_toml_path), 'PluginManager')
  return fs.read_file(plugins_toml_path):flat_map(toml_parser.parse):flat_map(PluginConfig.create)
end

---@param config spm.Config
---@param force_reinstall boolean?
---@return spm.Result<spm.PluginConfig>
local function get_plugin_config(config, force_reinstall)
  logger.debug('Getting plugin config', 'PluginManager')
  local plugins_toml_content_result = fs.read_file(config.plugins_toml_path)
  if plugins_toml_content_result:is_err() then
    logger.error('Failed to read plugins.toml', 'PluginManager')
    return plugins_toml_content_result
  end
  local plugins_toml_content = plugins_toml_content_result:unwrap()
  logger.debug('Successfully read plugins.toml', 'PluginManager')

  local lock_data_result = lock_manager.read(config.lock_file_path)
  if lock_data_result:is_err() then
    logger.error('Failed to read lock file', 'PluginManager')
    return lock_data_result
  end
  local lock_data = lock_data_result:unwrap()
  logger.debug('Successfully read lock file', 'PluginManager')

  if not lock_data or not lock_data.hash then
    logger.info('Lock file is missing. Installing/updating plugins.', 'PluginManager')
    return parse_config(config.plugins_toml_path)
  end

  local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)

  if force_reinstall or is_stale then
    logger.info('Lock file is stale or missing. Installing/updating plugins.', 'PluginManager')
    return parse_config(config.plugins_toml_path)
  else
    logger.info('Lock file is up to date. Verifying plugins from lock file.', 'PluginManager')
    return PluginConfig.create({
      plugins = lock_data.plugins or {},
      language_servers = lock_data.language_servers or {},
      filetypes = lock_data.filetypes or {},
    })
  end
end

---@param plugins spm.PluginSpec[]
---@param force_reinstall boolean?
---@param is_stale boolean
---@return spm.Result<nil>
local function install_plugins(plugins, force_reinstall, is_stale)
  local log_message = string.format('Verifying and loading %d plugins...', #plugins)
  if force_reinstall or is_stale then
    log_message = string.format('Installing %d plugins...', #plugins)
  end

  logger.info(log_message, 'PluginManager')
  return plugin_installer.install(plugins)
end

---@param config spm.Config
---@param parsed_config spm.PluginConfig
---@param flattened_plugins spm.PluginSpec[]
---@return spm.Result<nil>
local function update_lock_file(config, parsed_config, flattened_plugins)
  logger.info('Updating lock file now.', 'PluginManager')

  ---@type fun(plugins_toml_hash: string): spm.Result<table>
  local build_lock_data = function(hash)
    return {
      hash = hash,
      plugins = flattened_plugins,
      language_servers = parsed_config.language_servers,
      filetypes = parsed_config.filetypes,
    }
  end

  ---@type fun(lock_data: table): spm.Result<boolean>
  local write_lock_file = function(new_lock_data)
    return lock_manager.write(config.lock_file_path, new_lock_data)
  end

  return fs.read_file(config.plugins_toml_path)
    :flat_map(crypto.generate_hash)
    :flat_map(build_lock_data)
    :flat_map(write_lock_file)
end

---Sources configuration files in the specified order
---@param config_root string Root directory of the neovim config
---@param options table? Sourcing options
---@return spm.Result<nil>
local function source_configs(config_root, options)
  options = vim.tbl_deep_extend(
    'force',
    { enable_plugins = true, enable_keybindings = true, recursive = false },
    options or {}
  )

  local overall_success = true
  ---@type spm.Error[]
  local all_errors = {}
  local total_files_sourced = 0

  logger.info('Starting configuration file sourcing', 'PluginManager')

  local function source_path(path, is_dir)
    if is_dir then
      local result = file_sourcer.source_directory(path, options)
      if result:is_err() then
        overall_success = false
        table.insert(all_errors, result.error)
      else
        total_files_sourced = total_files_sourced + result:unwrap().files_sourced
      end
    else
      local result = file_sourcer.source_lua_file(path)
      if result:is_ok() then
        total_files_sourced = total_files_sourced + 1
        logger.debug('Sourced ' .. path, 'PluginManager')
      elseif vim.fn.filereadable(path) == 1 then
        overall_success = false
        table.insert(all_errors, result.error)
        logger.error(result.error.message, 'PluginManager')
      end
    end
  end

  if options.enable_plugins then
    source_path(config_root .. '/plugins.lua', false)
    source_path(config_root .. '/plugins', true)
  end

  if options.enable_keybindings then
    source_path(config_root .. '/keybindings.lua', false)
    source_path(config_root .. '/keybindings', true)
  end

  -- Log final results
  if overall_success then
    logger.info(
      string.format('Successfully sourced %d configuration files', total_files_sourced),
      'PluginManager'
    )
    return Result.ok(nil)
  else
    local error_summary = string.format('Failed to source %d files', #all_errors)
    logger.error(error_summary, 'PluginManager')
    return Result.err(error_summary)
  end
end

---Main method to install plugins and configure the system
---@type fun(config: spm.Config, force_reinstall: boolean?): spm.Result<nil>
---@param config spm.Config The full configuration object
---@param force_reinstall boolean? Whether to ignore the lock file and force reinstall
---@return spm.Result<nil>
local function setup(config, force_reinstall)
  logger.info('--- Starting PluginManager Setup ---', 'PluginManager')

  local config_result = get_plugin_config(config, force_reinstall)
  if config_result:is_err() then
    logger.error('Failed to get plugin config', 'PluginManager')
    return config_result
  end
  ---@type spm.PluginConfig
  local parsed_config = config_result:unwrap()
  logger.debug('Successfully got plugin config', 'PluginManager')

  local flattened_plugins = parsed_config:flatten_plugins()
  logger.debug(string.format('Found %d plugins to process', #flattened_plugins), 'PluginManager')

  local content_result = fs.read_file(config.plugins_toml_path)
  if content_result:is_err() then
    logger.error('Failed to read plugins.toml for stale check', 'PluginManager')
    return content_result
  end
  ---@type string
  local plugins_toml_content = content_result:unwrap()

  local lock_data_result = lock_manager.read(config.lock_file_path)
  if lock_data_result:is_err() then
    logger.error('Failed to read lock file for stale check', 'PluginManager')
    return lock_data_result
  end
  ---@type table
  local lock_data = lock_data_result:unwrap()

  local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)
  logger.debug(string.format('Lock file is stale: %s', tostring(is_stale)), 'PluginManager')

  local install_result = install_plugins(flattened_plugins, force_reinstall, is_stale)
  if install_result:is_err() then
    logger.error('Failed to install plugins', 'PluginManager')
    return install_result
  end
  logger.debug('Successfully installed plugins', 'PluginManager')

  if force_reinstall or is_stale then
    local update_lock_file_result = update_lock_file(config, parsed_config, flattened_plugins)
    if update_lock_file_result:is_err() then
      logger.error('Failed to update lock file', 'PluginManager')
      return update_lock_file_result
    end
    logger.debug('Successfully updated lock file', 'PluginManager')
  end

  logger.info('Sourcing user configuration files.', 'PluginManager')
  local source_configs_result = source_configs(vim.fn.stdpath('config'))
  if source_configs_result:is_err() then
    logger.error('Failed to source user configs', 'PluginManager')
    return source_configs_result
  end
  logger.debug('Successfully sourced user configs', 'PluginManager')

  logger.info('--- PluginManager Setup Finished ---', 'PluginManager')
  return Result.ok(nil)
end

---Debug method to show parsed plugins without installing
---@type fun(plugins_toml_path: string): spm.Result<spm.PluginSpec[]>
---@param plugins_toml_path string Path to the plugins.toml file
---@return spm.Result<spm.PluginSpec[]>
local function debug_plugins(plugins_toml_path)
  -- Logs the flattened plugins
  ---@type fun(flattened_plugins: spm.PluginSpec[]): spm.PluginSpec[]
  local log_flatten_plugins = function(flattened_plugins)
    logger.info(string.format('Found %d plugins', #flattened_plugins), 'PluginManager')
    for i, plugin in ipairs(flattened_plugins) do
      logger.info(
        string.format('  %d. %s -> %s', i, plugin.name or 'unnamed', plugin.src),
        'PluginManager'
      )
      if plugin.version then
        logger.info(string.format('     Version: %s', plugin.version), 'PluginManager')
      end
    end
    return flattened_plugins
  end

  return parse_config(plugins_toml_path)
    :map(function(config) return config:flatten_plugins() end)
    :map(log_flatten_plugins)
end

return {
  setup = setup,
  _debug_plugins = debug_plugins,
}
