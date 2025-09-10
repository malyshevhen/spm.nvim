local logger = require('spm.logger')
local lock_manager = require('spm.lock_manager')
local toml_parser = require('spm.toml_parser')
local pack_installer = require('spm.pack_installer')
local file_sourcer = require('spm.file_sourcer')
local crypto = require('spm.crypto')

---Reads file content
---@param file_path string
---@return string? content
---@return string? error
local function read_file(file_path)
  local file, err = io.open(file_path, 'r')
  if not file then
    return nil, 'Cannot open file: ' .. tostring(err)
  end
  local content = file:read('*a')
  file:close()
  return content
end

---Parses the plugins configuration file
---@param plugins_toml_path string Path to the plugins.toml file
---@return PluginConfig? config The parsed configuration
---@return string? error Error message if parsing fails
local function parse_config(plugins_toml_path)
  logger.info(string.format('Parsing configuration: %s', plugins_toml_path), 'PluginManager')

  local success, result = pcall(toml_parser.parse_plugins_toml, plugins_toml_path)
  if not success then
    local error_msg = string.format('Failed to parse plugins.toml: %s', result)
    logger.error(error_msg, 'PluginManager')

    return nil, error_msg
  elseif not result then
    local error_msg = string.format('Failed to parse plugins.toml: %s', result)
    logger.error(error_msg, 'PluginManager')

    return nil, error_msg
  end

  -- Validate the parsed configuration
  local valid, validation_error = result:validate()
  if not valid then
    local error_msg = string.format('Invalid plugin configuration: %s', validation_error)
    logger.error(error_msg, 'PluginManager')
    return nil, error_msg
  end

  logger.info(string.format('Found %d plugins', #result.plugins), 'PluginManager')
  return result, nil
end

---@param config SimplePMConfig
---@param force_reinstall boolean?
local function get_plugin_config(config, force_reinstall)
  local plugins_toml_content, read_err = read_file(config.plugins_toml_path)
  if not plugins_toml_content then
    local err_msg = 'Setup failed: could not read plugins.toml: ' .. (read_err or 'unknown')
    logger.error(err_msg, 'PluginManager')
    return nil, err_msg
  end

  local lock_data = lock_manager.read(config.lock_file_path)
  local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)

  if force_reinstall or is_stale then
    logger.info('Lock file is stale or missing. Installing/updating plugins.', 'PluginManager')
    return parse_config(config.plugins_toml_path)
  elseif lock_data then
    logger.info('Lock file is up to date. Verifying plugins from lock file.', 'PluginManager')
    return {
      plugins = lock_data.plugins or {},
      language_servers = lock_data.language_servers or {},
      filetypes = lock_data.filetypes or {},
    },
      nil
  else
    logger.error('Failed to read lock file', 'PluginManager')
    return nil, 'Failed to read lock file'
  end
end

---@param plugins PluginSpec[]
---@param force_reinstall boolean?
---@param is_stale boolean
local function install_plugins(plugins, force_reinstall, is_stale)
  local log_message = string.format('Verifying and loading %d plugins...', #plugins)
  if force_reinstall or is_stale then
    log_message = string.format('Installing %d plugins...', #plugins)
  end

  logger.info(log_message, 'PluginManager')
  local install_success, install_error = pack_installer.install(plugins)
  if not install_success then
    logger.error('Plugin setup failed during install/verify step.', 'PluginManager')
    return false, install_error
  end
  logger.info('Successfully verified and loaded all plugins.', 'PluginManager')
  return true
end

---@param config SimplePMConfig
---@param parsed_config PluginConfig
---@param flattened_plugins PluginSpec[]
local function update_lock_file(config, parsed_config, flattened_plugins)
  logger.info('Updating lock file now.', 'PluginManager')
  local plugins_toml_content, read_err = read_file(config.plugins_toml_path)
  if not plugins_toml_content then
    local err_msg = 'Setup failed: could not read plugins.toml: ' .. (read_err or 'unknown')
    logger.error(err_msg, 'PluginManager')
    return
  end

  local new_hash = crypto.generate_hash(plugins_toml_content)

  local new_lock_data = {
    hash = new_hash,
    plugins = flattened_plugins,
    language_servers = parsed_config.language_servers,
    filetypes = parsed_config.filetypes,
  }
  local ok, write_err = lock_manager.write(config.lock_file_path, new_lock_data)
  if not ok then
    logger.error('Failed to write lock file: ' .. (write_err or 'unknown error'), 'PluginManager')
  else
    logger.info('Lock file successfully written.', 'PluginManager')
  end
end

---Main method to install plugins and configure the system
---@param config SimplePMConfig The full configuration object
---@param force_reinstall boolean? Whether to ignore the lock file and force reinstall
---@return boolean success True if the entire process was successful
---@return string? error Error message if any step fails
local function setup(config, force_reinstall)
  logger.info('--- Starting PluginManager Setup ---', 'PluginManager')

  local parsed_config, err = get_plugin_config(config, force_reinstall)
  if err then
    return false, err
  end

  if not parsed_config then
    return false, 'Failed to get plugin config'
  end

  local flattened_plugins = parsed_config:flatten_plugins()

  local plugins_toml_content = read_file(config.plugins_toml_path)
  if not plugins_toml_content then
    return false, 'Failed to read plugins.toml'
  end

  local lock_data = lock_manager.read(config.lock_file_path)
  local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)

  local ok, install_err = install_plugins(flattened_plugins, force_reinstall, is_stale)
  if not ok then
    return false, install_err
  end

  if force_reinstall or is_stale then
    update_lock_file(config, parsed_config, flattened_plugins)
  end

  logger.info('Sourcing user configuration files.', 'PluginManager')
  local source_success, source_error = file_sourcer.source_configs(config.config_root)
  if not source_success then
    return false, source_error
  end

  logger.info('--- PluginManager Setup Finished ---', 'PluginManager')
  return true, nil
end

---Debug method to show parsed plugins without installing
---@param plugins_toml_path string Path to the plugins.toml file
---@return PluginSpec[]? plugins List of parsed plugins
---@return string? error Error message if parsing fails
local function debug_plugins(plugins_toml_path)
  local config, error_msg = parse_config(plugins_toml_path)
  if not config then
    return nil, error_msg
  end

  local flattened_plugins = config:flatten_plugins()

  -- Output debug information
  print(string.format('Found %d plugins:', #flattened_plugins))
  for i, plugin in ipairs(flattened_plugins) do
    print(string.format('  %d. %s -> %s', i, plugin.name or 'unnamed', plugin.src))
    if plugin.version then
      print(string.format('     Version: %s', plugin.version))
    end
  end

  return flattened_plugins, nil
end

return {
  setup = setup,
  _debug_plugins = debug_plugins,
}
