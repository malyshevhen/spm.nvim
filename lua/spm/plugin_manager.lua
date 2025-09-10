local logger = require('spm.logger')
local plugin_types = require('spm.plugin_types')
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
  logger.info(string.format('Parsing configuration: %s', plugins_toml_path))

  local success, result = pcall(toml_parser.parse_plugins_toml, plugins_toml_path)
  if not success then
    local error_msg = string.format('Failed to parse plugins.toml: %s', result)
    logger.error(error_msg)
    return nil, error_msg
  end

  -- Validate the parsed configuration
  local valid, validation_error = plugin_types.validate_config(result)
  if not valid then
    local error_msg = string.format('Invalid plugin configuration: %s', validation_error)
    logger.error(error_msg)
    return nil, error_msg
  end

  logger.info(string.format('Found %d plugins', #result.plugins))
  return result, nil
end

---Flattens plugins configuration including dependencies
---@param config PluginConfig The plugin configuration
---@return PluginSpec[] flattened_plugins All plugins as individual entries
local function flatten_plugins(config)
  logger.info('Flattening plugin dependencies')

  local flattened = plugin_types.flatten_plugins(config)

  logger.info(string.format('Flattened to %d total plugins', #flattened))
  return flattened
end

---Installs all plugins using the pack installer
---@param plugins PluginSpec[] List of plugins to install
---@return boolean success True if installation was successful
---@return string? error Error message if installation fails
local function install_plugins(plugins)
  if #plugins == 0 then
    logger.warn('No plugins to install')
    return true, nil
  end

  local success, error_msg = pack_installer.install(plugins)

  if not success then
    logger.error(error_msg or 'Plugin installation failed')
  end

  return success, error_msg
end

---Sources configuration files after plugin installation
---@param config_root string Root directory of the configuration
---@return boolean success True if sourcing was successful
---@return string? error Error message if sourcing fails
local function source_configs(config_root)
  logger.info('Sourcing configuration files')

  local success, error_msg = file_sourcer.source_configs(config_root)

  if success then
    logger.info('Configuration files sourced successfully')
  else
    logger.error(error_msg or 'Configuration sourcing failed')
  end

  return success, error_msg
end

---Enables language servers
---@param ls_config table Language server configuration
local function enable_language_servers(ls_config)
  if not ls_config or not ls_config.servers or #ls_config.servers == 0 then
    logger.info('No language servers to enable.')
    return
  end

  logger.info('Enabling ' .. #ls_config.servers .. ' language servers.')

  -- Try enabling servers individually by loading their config files
  local enabled_count = 0
  local failed_servers = {}

  for _, server in ipairs(ls_config.servers) do
    local config_path = 'lsp/' .. server
    local success, config = pcall(require, config_path)

    if success and config then
      local enable_success, enable_err = pcall(vim.lsp.config, server, config)
      if enable_success then
        enabled_count = enabled_count + 1
        -- Also call vim.lsp.enable with the server name
        local _, _ = pcall(vim.lsp.enable, server)
      else
        table.insert(failed_servers, server)
        logger.error('Failed to configure LSP server "' .. server .. '": ' .. tostring(enable_err))
      end
    else
      -- Fallback to simple enable if no config file found
      local enable_success, enable_err = pcall(vim.lsp.enable, server)
      if enable_success then
        enabled_count = enabled_count + 1
      else
        table.insert(failed_servers, server)
        logger.error('Failed to enable LSP server "' .. server .. '": ' .. tostring(enable_err))
      end
    end
  end

  if enabled_count > 0 then
    logger.info('Successfully enabled ' .. enabled_count .. ' language servers.')
  end

  if #failed_servers > 0 then
    logger.error(
      'Failed to enable '
        .. #failed_servers
        .. ' language servers: '
        .. table.concat(failed_servers, ', ')
    )
  end
end

---Adds custom filetype mappings
---@param filetypes_config table Filetype configuration
local function add_filetypes(filetypes_config)
  if not filetypes_config or not filetypes_config.pattern then
    logger.info('No custom filetypes to add.')
    return
  end

  logger.info('Adding custom filetype mappings.')
  local success, err = pcall(vim.filetype.add, filetypes_config)
  if not success then
    logger.error('Failed to add filetypes: ' .. tostring(err))
  end
end

---Main method to install plugins and configure the system
---@param config SimplePMConfig The full configuration object
---@param force_reinstall boolean? Whether to ignore the lock file and force reinstall
---@return boolean success True if the entire process was successful
---@return string? error Error message if any step fails
local function setup(config, force_reinstall)
  logger.info('--- Starting PluginManager Setup ---')

  local plugins_toml_content, read_err = read_file(config.plugins_toml_path)
  if not plugins_toml_content then
    local err_msg = 'Setup failed: could not read plugins.toml: ' .. (read_err or 'unknown')
    logger.error(err_msg)
    return false, err_msg
  end

  local lock_data = lock_manager.read(config.lock_file_path)
  logger.debug('Read lock_data: ' .. vim.inspect(lock_data))

  local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)

  local flattened_plugins
  local language_servers_config
  local filetypes_config

  if not force_reinstall and not is_stale and lock_data and lock_data.plugins then
    logger.info('Lock file is up to date. Verifying plugins from lock file.')
    flattened_plugins = lock_data.plugins
    language_servers_config = lock_data.language_servers
    filetypes_config = lock_data.filetypes

    -- Fallback: if language_servers_config is corrupted, reparse the TOML
    if
      not language_servers_config
      or not language_servers_config.servers
      or #language_servers_config.servers == 0
    then
      logger.warn('Language servers config corrupted in lock file, reparsing TOML')
      local parsed_config, parse_error = parse_config(config.plugins_toml_path)
      if parsed_config and parsed_config.language_servers then
        language_servers_config = parsed_config.language_servers
      end
    end
  else
    logger.info('Lock file is stale or missing. Installing/updating plugins.')
    local parsed_config, parse_error = parse_config(config.plugins_toml_path)
    if not parsed_config then
      return false, parse_error
    end
    flattened_plugins = flatten_plugins(parsed_config)
    language_servers_config = parsed_config.language_servers
    filetypes_config = parsed_config.filetypes
  end

  logger.debug(
    'Using plugin_config: '
      .. vim.inspect({ plugins = flattened_plugins, language_servers = language_servers_config })
  )

  local log_message = string.format('Verifying and loading %d plugins...', #flattened_plugins)
  if force_reinstall or is_stale then
    log_message = string.format('Installing %d plugins...', #flattened_plugins)
  end

  logger.info(log_message)
  local install_success, install_error = install_plugins(flattened_plugins)
  if not install_success then
    logger.error('Plugin setup failed during install/verify step.')
    return false, install_error
  end
  logger.info('Successfully verified and loaded all plugins.')

  if force_reinstall or is_stale then
    logger.info('Updating lock file now.')
    local new_hash = crypto.generate_hash(plugins_toml_content)

    local plugin_names = {}
    for _, p in ipairs(flattened_plugins) do
      if p.name then
        table.insert(plugin_names, p.name)
      end
    end

    local installed_info, info_err = pack_installer.get_info(plugin_names)
    if not installed_info then
      logger.warn('Could not get installed plugin info: ' .. (info_err or 'unknown error'))
    end

    local version_map = {}
    if installed_info then
      for _, info in ipairs(installed_info) do
        if info.git_spec and info.git_spec.url and info.git_spec.rev then
          version_map[info.git_spec.url] = info.git_spec.rev
        end
      end
    end

    local plugins_for_lock = vim.deepcopy(flattened_plugins)
    for _, p in ipairs(plugins_for_lock) do
      if version_map[p.src] then
        p.version = version_map[p.src]
      end
    end

    local new_lock_data = {
      hash = new_hash,
      plugins = plugins_for_lock,
      language_servers = language_servers_config,
      filetypes = filetypes_config,
    }
    logger.debug('Writing new_lock_data: ' .. vim.inspect(new_lock_data))
    local ok, write_err = lock_manager.write(config.lock_file_path, new_lock_data)
    if not ok then
      logger.error('Failed to write lock file: ' .. (write_err or 'unknown error'))
    else
      logger.info('Lock file successfully written.')
    end
  else
    logger.info('Lock file is up to date. No update needed.')
  end

  logger.info('Sourcing user configuration files.')
  local source_success, source_error = source_configs(config.config_root)
  if not source_success then
    return false, source_error
  end

  add_filetypes(filetypes_config or {})
  enable_language_servers(language_servers_config or {})

  logger.info('--- PluginManager Setup Finished ---')
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

  local flattened_plugins = flatten_plugins(config)

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
