local crypto = require('spm.lib.crypto')
local file_sourcer = require('spm.lib.file_sourcer')
local fs = require('spm.lib.fs')
local lock_manager = require('spm.core.lock_manager')
local logger = require('spm.lib.logger')
local plugin_installer = require('spm.core.plugin_installer')
local plugin_types = require('spm.core.plugin_types')
local toml_parser = require('spm.lib.toml_parser')
local PluginConfig = plugin_types.PluginConfig

---Parses the plugins configuration file
---@param plugins_toml_path string Path to the plugins.toml file
---@return table?, string?
local function parse_config(plugins_toml_path)
  logger.info(string.format('Parsing configuration: %s', plugins_toml_path), 'PluginManager')
  local plugins_toml_content, err = fs.read_file(plugins_toml_path)
  if err or not plugins_toml_content then
    logger.error('Failed to read plugins.toml', 'PluginManager')
    return nil, err
  end
  logger.debug('Successfully read plugins.toml', 'PluginManager')

  local parsed_content, parse_err = toml_parser.parse(plugins_toml_content)
  if parse_err then
    logger.error('Failed to parse plugins.toml', 'PluginManager')
    return nil, parse_err
  end
  logger.debug('Successfully parsed plugins.toml', 'PluginManager')

  return PluginConfig.create(parsed_content)
end

---@param config spm.Config
---@param force_reinstall boolean?
---@return table?, string?
local function get_plugin_config(config, force_reinstall)
  logger.debug('Getting plugin config', 'PluginManager')
  local plugins_toml_content, err = fs.read_file(config.plugins_toml_path)
  if err or not plugins_toml_content then
    logger.error('Failed to read plugins.toml', 'PluginManager')
    return nil, err
  end
  logger.debug('Successfully read plugins.toml', 'PluginManager')

  local lock_data, lock_err = lock_manager.read(config.lock_file_path)
  if lock_err then
    logger.error('Failed to read lock file', 'PluginManager')
    return nil, lock_err
  end
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
---@return boolean?, string?
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
---@return boolean?, string?
local function update_lock_file(config, parsed_config, flattened_plugins)
  logger.info('Updating lock file now.', 'PluginManager')

  local plugins_toml_content, err = fs.read_file(config.plugins_toml_path)
  if err or not plugins_toml_content then
    logger.error('Failed to read plugins.toml', 'PluginManager')
    return nil, err
  end
  logger.debug('Successfully read plugins.toml', 'PluginManager')

  local hash, hash_err = crypto.generate_hash(plugins_toml_content)
  if hash_err then
    logger.error('Failed to generate hash', 'PluginManager')
    return nil, hash_err
  end
  logger.debug('Successfully generated hash', 'PluginManager')

  local lock_data = {
    hash = hash,
    plugins = flattened_plugins,
    language_servers = parsed_config.language_servers,
    filetypes = parsed_config.filetypes,
  }
  logger.debug('Successfully built lock data', 'PluginManager')

  return lock_manager.write(config.lock_file_path, lock_data)
end

---Sources configuration files in the specified order
---@param config_root string Root directory of the neovim config
---@param options table? Sourcing options
---@return boolean?, string?
local function source_configs(config_root, options)
  options = vim.tbl_deep_extend(
    'force',
    { enable_plugins = true, enable_keybindings = true, recursive = false },
    options or {}
  )

  local overall_success = true
  local total_files_sourced = 0

  logger.info('Starting configuration file sourcing', 'PluginManager')

  local function source_path(path, is_dir)
    if is_dir then
      local result, err = file_sourcer.source_directory(path, options)
      if err or not result then
        overall_success = false
        logger.error('Failed to source directory ' .. path .. ': ' .. err, 'PluginManager')
      else
        total_files_sourced = total_files_sourced + result.files_sourced
      end
    else
      local ok, src_err = file_sourcer.source_lua_file(path)
      if ok or not src_err then
        total_files_sourced = total_files_sourced + 1
        logger.debug('Sourced ' .. path, 'PluginManager')
      elseif vim.fn.filereadable(path) == 1 then
        overall_success = false
        logger.error(src_err, 'PluginManager')
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
    return true
  else
    local error_summary = 'Failed to source some files'
    logger.error(error_summary, 'PluginManager')
    return nil, error_summary
  end
end

---Main method to install plugins and configure the system
---@param config spm.Config The full configuration object
---@param force_reinstall boolean? Whether to ignore the lock file and force reinstall
---@return boolean?, string?
local function setup(config, force_reinstall)
  logger.info('--- Starting PluginManager Setup ---', 'PluginManager')

  local parsed_config, err = get_plugin_config(config, force_reinstall)
  if err or not parsed_config then
    logger.error('Failed to get plugin config', 'PluginManager')
    return nil, err
  end
  logger.debug('Successfully got plugin config', 'PluginManager')

  local flattened_plugins = parsed_config:flatten_plugins()
  logger.debug(string.format('Found %d plugins to process', #flattened_plugins), 'PluginManager')

  local plugins_toml_content, content_err = fs.read_file(config.plugins_toml_path)
  if content_err or not plugins_toml_content then
    logger.error('Failed to read plugins.toml for stale check', 'PluginManager')
    return nil, content_err
  end

  local lock_data, lock_err = lock_manager.read(config.lock_file_path)
  if lock_err then
    logger.error('Failed to read lock file for stale check', 'PluginManager')
    return nil, lock_err
  end

  local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)
  logger.debug(string.format('Lock file is stale: %s', tostring(is_stale)), 'PluginManager')

  local install_ok, install_err = install_plugins(flattened_plugins, force_reinstall, is_stale)
  if not install_ok then
    logger.error('Failed to install plugins', 'PluginManager')
    return nil, install_err
  end
  logger.debug('Successfully installed plugins', 'PluginManager')

  if force_reinstall or is_stale then
    local update_ok, update_err = update_lock_file(config, parsed_config, flattened_plugins)
    if not update_ok then
      logger.error('Failed to update lock file', 'PluginManager')
      return nil, update_err
    end
    logger.debug('Successfully updated lock file', 'PluginManager')
  end

  logger.info('Sourcing user configuration files.', 'PluginManager')
  local source_ok, source_err = source_configs(vim.fn.stdpath('config'))
  if source_err or not source_ok then
    logger.error('Failed to source user configs', 'PluginManager')
    return nil, source_err
  end
  logger.debug('Successfully sourced user configs', 'PluginManager')

  logger.info('--- PluginManager Setup Finished ---', 'PluginManager')
  return true
end

---Debug method to show parsed plugins without installing
---@param plugins_toml_path string Path to the plugins.toml file
---@return table?, string?
local function debug_plugins(plugins_toml_path)
  -- Logs the flattened plugins
  local parsed_config, err = parse_config(plugins_toml_path)
  if err or not parsed_config then return nil, err end

  local flattened_plugins = parsed_config:flatten_plugins()

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

return {
  setup = setup,
  _debug_plugins = debug_plugins,
}
