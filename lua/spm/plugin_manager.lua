---@class PluginManager
local M = {}

local logger = require('spm.logger')
local plugin_types = require('spm.plugin_types')

---@class PluginManagerDependencies
---@field toml_parser table TOML parser implementation
---@field pack_installer table vim.pack installer wrapper
---@field file_sourcer table File sourcing implementation
---@field crypto table Crypto implementation
---@field lock_manager LockManager Lock manager implementation

---@class PluginManager
---@field dependencies PluginManagerDependencies
---@field logger table Contextual logger
local PluginManager = {}
PluginManager.__index = PluginManager

---Creates a new plugin manager instance
---@param dependencies PluginManagerDependencies Required dependencies
---@return PluginManager
function M.new(dependencies)
  if not dependencies then
    error('PluginManager requires dependencies')
  end

  local required_deps = {
    'toml_parser',
    'pack_installer',
    'file_sourcer',
    'crypto',
    'lock_manager',
  }
  for _, dep in ipairs(required_deps) do
    if not dependencies[dep] then
      error(string.format('Missing required dependency: %s', dep))
    end
  end

  local instance = setmetatable({
    dependencies = dependencies,
    logger = logger.create_context('PluginManager'),
  }, PluginManager)

  return instance
end

---Reads file content
---@param file_path string
---@return string? content
---@return string? error
function PluginManager:read_file(file_path)
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
function PluginManager:parse_config(plugins_toml_path)
  self.logger.info(string.format('Parsing configuration: %s', plugins_toml_path))

  local success, result = pcall(self.dependencies.toml_parser.parse_plugins_toml, plugins_toml_path)
  if not success then
    local error_msg = string.format('Failed to parse plugins.toml: %s', result)
    self.logger.error(error_msg)
    return nil, error_msg
  end

  -- Validate the parsed configuration
  local valid, validation_error = plugin_types.validate_config(result)
  if not valid then
    local error_msg = string.format('Invalid plugin configuration: %s', validation_error)
    self.logger.error(error_msg)
    return nil, error_msg
  end

  self.logger.info(string.format('Found %d plugins', #result.plugins))
  return result, nil
end

---Flattens plugins configuration including dependencies
---@param config PluginConfig The plugin configuration
---@return PluginSpec[] flattened_plugins All plugins as individual entries
function PluginManager:flatten_plugins(config)
  self.logger.info('Flattening plugin dependencies')

  local flattened = plugin_types.flatten_plugins(config)

  self.logger.info(string.format('Flattened to %d total plugins', #flattened))
  return flattened
end

---Installs all plugins using the pack installer
---@param plugins PluginSpec[] List of plugins to install
---@return boolean success True if installation was successful
---@return string? error Error message if installation fails
function PluginManager:install_plugins(plugins)
  if #plugins == 0 then
    self.logger.warn('No plugins to install')
    return true, nil
  end

  local success, error_msg = self.dependencies.pack_installer.install(plugins)

  if not success then
    self.logger.error(error_msg or 'Plugin installation failed')
  end

  return success, error_msg
end

---Sources configuration files after plugin installation
---@param config_root string Root directory of the configuration
---@return boolean success True if sourcing was successful
---@return string? error Error message if sourcing fails
function PluginManager:source_configs(config_root)
  self.logger.info('Sourcing configuration files')

  local success, error_msg = self.dependencies.file_sourcer.source_configs(config_root)

  if success then
    self.logger.info('Configuration files sourced successfully')
  else
    self.logger.error(error_msg or 'Configuration sourcing failed')
  end

  return success, error_msg
end

---Enables language servers
---@param ls_config table Language server configuration
function PluginManager:enable_language_servers(ls_config)
  if not ls_config or not ls_config.servers or #ls_config.servers == 0 then
    self.logger.info('No language servers to enable.')
    return
  end

  self.logger.info('Enabling ' .. #ls_config.servers .. ' language servers.')

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
        self.logger.error(
          'Failed to configure LSP server "' .. server .. '": ' .. tostring(enable_err)
        )
      end
    else
      -- Fallback to simple enable if no config file found
      local enable_success, enable_err = pcall(vim.lsp.enable, server)
      if enable_success then
        enabled_count = enabled_count + 1
      else
        table.insert(failed_servers, server)
        self.logger.error(
          'Failed to enable LSP server "' .. server .. '": ' .. tostring(enable_err)
        )
      end
    end
  end

  if enabled_count > 0 then
    self.logger.info('Successfully enabled ' .. enabled_count .. ' language servers.')
  end

  if #failed_servers > 0 then
    self.logger.error(
      'Failed to enable '
        .. #failed_servers
        .. ' language servers: '
        .. table.concat(failed_servers, ', ')
    )
  end
end

---Adds custom filetype mappings
---@param filetypes_config table Filetype configuration
function PluginManager:add_filetypes(filetypes_config)
  if not filetypes_config or not filetypes_config.pattern then
    self.logger.info('No custom filetypes to add.')
    return
  end

  self.logger.info('Adding custom filetype mappings.')
  local success, err = pcall(vim.filetype.add, filetypes_config)
  if not success then
    self.logger.error('Failed to add filetypes: ' .. tostring(err))
  end
end

---Main method to install plugins and configure the system
---@param config SimplePMConfig The full configuration object
---@param force_reinstall boolean? Whether to ignore the lock file and force reinstall
---@return boolean success True if the entire process was successful
---@return string? error Error message if any step fails
function PluginManager:setup(config, force_reinstall)
  self.logger.info('--- Starting PluginManager Setup ---')

  local plugins_toml_content, read_err = self:read_file(config.plugins_toml_path)
  if not plugins_toml_content then
    local err_msg = 'Setup failed: could not read plugins.toml: ' .. (read_err or 'unknown')
    self.logger.error(err_msg)
    return false, err_msg
  end

  local lock_data = self.dependencies.lock_manager:read(config.lock_file_path)
  self.logger.debug('Read lock_data: ' .. vim.inspect(lock_data))

  local is_stale = self.dependencies.lock_manager:is_stale(plugins_toml_content, lock_data)

  local flattened_plugins
  local language_servers_config
  local filetypes_config

  if not force_reinstall and not is_stale and lock_data and lock_data.plugins then
    self.logger.info('Lock file is up to date. Verifying plugins from lock file.')
    flattened_plugins = lock_data.plugins
    language_servers_config = lock_data.language_servers
    filetypes_config = lock_data.filetypes

    -- Fallback: if language_servers_config is corrupted, reparse the TOML
    if
      not language_servers_config
      or not language_servers_config.servers
      or #language_servers_config.servers == 0
    then
      self.logger.warn('Language servers config corrupted in lock file, reparsing TOML')
      local parsed_config, parse_error = self:parse_config(config.plugins_toml_path)
      if parsed_config and parsed_config.language_servers then
        language_servers_config = parsed_config.language_servers
      end
    end
  else
    self.logger.info('Lock file is stale or missing. Installing/updating plugins.')
    local parsed_config, parse_error = self:parse_config(config.plugins_toml_path)
    if not parsed_config then
      return false, parse_error
    end
    flattened_plugins = self:flatten_plugins(parsed_config)
    language_servers_config = parsed_config.language_servers
    filetypes_config = parsed_config.filetypes
  end

  self.logger.debug(
    'Using plugin_config: '
      .. vim.inspect({ plugins = flattened_plugins, language_servers = language_servers_config })
  )

  local log_message = string.format('Verifying and loading %d plugins...', #flattened_plugins)
  if force_reinstall or is_stale then
    log_message = string.format('Installing %d plugins...', #flattened_plugins)
  end

  self.logger.info(log_message)
  local install_success, install_error = self:install_plugins(flattened_plugins)
  if not install_success then
    self.logger.error('Plugin setup failed during install/verify step.')
    return false, install_error
  end
  self.logger.info('Successfully verified and loaded all plugins.')

  if force_reinstall or is_stale then
    self.logger.info('Updating lock file now.')
    local new_hash = self.dependencies.crypto.generate_hash(plugins_toml_content)

    local plugin_names = {}
    for _, p in ipairs(flattened_plugins) do
      if p.name then
        table.insert(plugin_names, p.name)
      end
    end

    local installed_info, info_err = self.dependencies.pack_installer.get_info(plugin_names)
    if not installed_info then
      self.logger.warn('Could not get installed plugin info: ' .. (info_err or 'unknown error'))
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
    self.logger.debug('Writing new_lock_data: ' .. vim.inspect(new_lock_data))
    local ok, write_err = self.dependencies.lock_manager:write(config.lock_file_path, new_lock_data)
    if not ok then
      self.logger.error('Failed to write lock file: ' .. (write_err or 'unknown error'))
    else
      self.logger.info('Lock file successfully written.')
    end
  else
    self.logger.info('Lock file is up to date. No update needed.')
  end

  self.logger.info('Sourcing user configuration files.')
  local source_success, source_error = self:source_configs(config.config_root)
  if not source_success then
    return false, source_error
  end

  self:add_filetypes(filetypes_config)
  self:enable_language_servers(language_servers_config)

  self.logger.info('--- PluginManager Setup Finished ---')
  return true, nil
end

---Debug method to show parsed plugins without installing
---@param plugins_toml_path string Path to the plugins.toml file
---@return PluginSpec[]? plugins List of parsed plugins
---@return string? error Error message if parsing fails
function PluginManager:debug_plugins(plugins_toml_path)
  local config, error_msg = self:parse_config(plugins_toml_path)
  if not config then
    return nil, error_msg
  end

  local flattened_plugins = self:flatten_plugins(config)

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

return M
