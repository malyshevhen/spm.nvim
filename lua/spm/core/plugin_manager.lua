local logger = require('spm.lib.logger')
local lock_manager = require('spm.core.lock_manager')
local toml_parser = require('spm.toml_parser')
local pack_installer = require('spm.core.pack_installer')
local file_sourcer = require('spm.lib.file_sourcer')
local crypto = require('spm.lib.crypto')
local Result = require('spm.lib.error').Result

---Reads file content
---@param file_path string
---@return Result<string>
local function read_file(file_path)
  return Result.try(function()
    local file, read_err = io.open(file_path, 'r')
    if not file then error('Cannot open file: ' .. (read_err or 'Unknown error')) end

    ---@type string
    local content = file:read('*a')
    local ok, close_err = file:close()
    if not ok then error('Cannot close file: ' .. (close_err or 'Unknown error')) end

    return content
  end)
end

---Parses the plugins configuration file
---@param plugins_toml_path string Path to the plugins.toml file
---@return Result<PluginConfig>
local function parse_config(plugins_toml_path)
  logger.info(string.format('Parsing configuration: %s', plugins_toml_path), 'PluginManager')

  ---@type fun(config: PluginConfig): Result<PluginConfig>
  local validate_config = function(config)
    local result = config:validate()
    if result:is_ok() then
      logger.info(string.format('Found %d plugins', #config.plugins), 'PluginManager')
    end

    return result
  end

  return toml_parser.parse_plugins_toml(plugins_toml_path):flat_map(validate_config)
end

---@param config SimplePMConfig
---@param force_reinstall boolean?
---@return Result<PluginConfig>
local function get_plugin_config(config, force_reinstall)
  local parse_plugins_file = function(plugins_toml_content)
    return function(lock_data)
      local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)
      if force_reinstall or is_stale then
        logger.info('Lock file is stale or missing. Installing/updating plugins.', 'PluginManager')
        return parse_config(config.plugins_toml_path)
      elseif lock_data then
        logger.info('Lock file is up to date. Verifying plugins from lock file.', 'PluginManager')

        return Result.ok({
          plugins = lock_data.plugins or {},
          language_servers = lock_data.language_servers or {},
          filetypes = lock_data.filetypes or {},
        })
      else
        return Result.err('Failed to read lock file')
      end
    end
  end

  return read_file(config.plugins_toml_path):flat_map(
    function(plugins_toml_content)
      return lock_manager
        .read(config.lock_file_path)
        :flat_map(parse_plugins_file(plugins_toml_content))
    end
  )
end

---@param plugins PluginSpec[]
---@param force_reinstall boolean?
---@param is_stale boolean
---@return Result<nil>
local function install_plugins(plugins, force_reinstall, is_stale)
  local log_message = string.format('Verifying and loading %d plugins...', #plugins)
  if force_reinstall or is_stale then
    log_message = string.format('Installing %d plugins...', #plugins)
  end

  logger.info(log_message, 'PluginManager')
  return pack_installer(plugins)
end

---@param config SimplePMConfig
---@param parsed_config PluginConfig
---@param flattened_plugins PluginSpec[]
---@return Result<nil>
local function update_lock_file(config, parsed_config, flattened_plugins)
  logger.info('Updating lock file now.', 'PluginManager')

  ---@type fun(plugins_toml_hash: string): Result<table>
  local build_lock_data = function(hash)
    return {
      hash = hash,
      plugins = flattened_plugins,
      language_servers = parsed_config.language_servers,
      filetypes = parsed_config.filetypes,
    }
  end

  ---@type fun(lock_data: table): Result<string>
  local write_lock_file = function(new_lock_data)
    return lock_manager.write(config.lock_file_path, new_lock_data)
  end

  return read_file(config.plugins_toml_path)
    :map(crypto.generate_hash)
    :map(build_lock_data)
    :map(write_lock_file)
end

---Sources configuration files in the specified order
---@param config_root string Root directory of the neovim config
---@param options table? Sourcing options
---@return Result<nil>
local function source_configs(config_root, options)
  options = vim.tbl_deep_extend(
    'force',
    { enable_plugins = true, enable_keybindings = true, recursive = false },
    options or {}
  )

  local overall_success = true
  ---@type Error[]
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
---@type fun(config: SimplePMConfig, force_reinstall: boolean?): Result<nil>
---@param config SimplePMConfig The full configuration object
---@param force_reinstall boolean? Whether to ignore the lock file and force reinstall
---@return Result<nil>
local function setup(config, force_reinstall)
  logger.info('--- Starting PluginManager Setup ---', 'PluginManager')

  local config_result = get_plugin_config(config, force_reinstall)
  if config_result:is_err() then return config_result end
  ---@type PluginConfig
  local parsed_config = config_result:unwrap()

  local flattened_plugins = parsed_config:flatten_plugins()

  local content_result = read_file(config.plugins_toml_path)
  if content_result:is_err() then return content_result end
  ---@type string
  local plugins_toml_content = content_result:unwrap()

  local lock_data_result = lock_manager.read(config.lock_file_path)
  if lock_data_result:is_err() then return lock_data_result end
  ---@type table
  local lock_data = lock_data_result:unwrap()

  local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)

  local install_result = install_plugins(flattened_plugins, force_reinstall, is_stale)
  if install_result:is_err() then return install_result end

  if force_reinstall or is_stale then
    local update_lock_file_result = update_lock_file(config, parsed_config, flattened_plugins)
    if update_lock_file_result:is_err() then return update_lock_file_result end
  end

  logger.info('Sourcing user configuration files.', 'PluginManager')
  local source_configs_result = source_configs(vim.fn.stdpath('config'))
  if source_configs_result:is_err() then return source_configs_result end

  logger.info('--- PluginManager Setup Finished ---', 'PluginManager')
  return Result.ok(nil)
end

---Debug method to show parsed plugins without installing
---@type fun(plugins_toml_path: string): Result<PluginSpec[]>
---@param plugins_toml_path string Path to the plugins.toml file
---@return Result<PluginSpec[]>
local function debug_plugins(plugins_toml_path)
  -- Logs the flattened plugins
  ---@type fun(flattened_plugins: PluginSpec[]): PluginSpec[]
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
