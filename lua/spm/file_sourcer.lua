local logger = require('spm.logger')

---@class FileSourcerOptions
---@field enable_plugins boolean Whether to source plugins configuration
---@field enable_keybindings boolean Whether to source keybindings configuration
---@field recursive boolean Whether to source directories recursively (not recommended)

---Default options for file sourcing
---@type FileSourcerOptions
local DEFAULT_OPTIONS = {
  enable_plugins = true,
  enable_keybindings = true,
  recursive = false,
}

---@class SourceResult
---@field success boolean Whether the operation was successful
---@field files_sourced number Number of files successfully sourced
---@field errors table[] List of errors encountered

---Safely sources a single Lua file
---@param filepath string Path to the Lua file to source
---@return boolean success True if the file was sourced successfully
---@return string? error Error message if sourcing failed
local function source_lua_file(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    return false, string.format('File not readable: %s', filepath)
  end

  local success, err = pcall(dofile, filepath)
  if not success then
    return false, string.format('Error sourcing %s: %s', filepath, err)
  end

  return true, nil
end

---Gets all Lua files in a directory
---@param dirpath string Path to the directory
---@param recursive boolean Whether to search recursively
---@return string[] filepaths List of Lua file paths found
local function get_lua_files(dirpath, recursive)
  if vim.fn.isdirectory(dirpath) == 0 then
    return {}
  end

  local pattern = recursive and '**/*.lua' or '*.lua'
  local glob_pattern = dirpath .. '/' .. pattern

  return vim.fn.glob(glob_pattern, false, true)
end

---Sources all Lua files in a directory
---@param dirpath string Path to the directory
---@param options FileSourcerOptions Sourcing options
---@return SourceResult result Result of the sourcing operation
local function source_directory(dirpath, options)
  local result = {
    success = true,
    files_sourced = 0,
    errors = {},
  }

  local files = get_lua_files(dirpath, options.recursive)

  for _, filepath in ipairs(files) do
    local success, error_msg = source_lua_file(filepath)
    if success then
      result.files_sourced = result.files_sourced + 1
      logger.debug(string.format('Sourced: %s', filepath), 'FileSourcer')
    else
      result.success = false
      table.insert(result.errors, {
        file = filepath,
        error = error_msg,
      })
      logger.error(error_msg or 'Unknown error', 'FileSourcer')
    end
  end

  return result
end

---Sources configuration files in the specified order
---@param config_root string Root directory of the neovim config
---@param options FileSourcerOptions? Sourcing options
---@return boolean success True if sourcing was successful
---@return string? error Error message if sourcing fails
local function source_configs(config_root, options)
  options = vim.tbl_deep_extend('force', DEFAULT_OPTIONS, options or {})

  local overall_success = true
  local all_errors = {}
  local total_files_sourced = 0

  logger.info('Starting configuration file sourcing', 'FileSourcer')

  local function source_path(path, is_dir)
    if is_dir then
      local result = source_directory(path, options)
      total_files_sourced = total_files_sourced + result.files_sourced
      if not result.success then
        overall_success = false
        for _, error_info in ipairs(result.errors) do
          table.insert(all_errors, error_info)
        end
      end
    else
      local success, error_msg = source_lua_file(path)
      if success then
        total_files_sourced = total_files_sourced + 1
        logger.debug('Sourced ' .. path, 'FileSourcer')
      elseif vim.fn.filereadable(path) == 1 then
        overall_success = false
        local safe_error = error_msg or 'Unknown error'
        table.insert(all_errors, { file = path, error = safe_error })
        logger.error(safe_error, 'FileSourcer')
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
      'FileSourcer'
    )
    return true, nil
  else
    local error_summary = string.format('Failed to source %d files', #all_errors)
    logger.error(error_summary, 'FileSourcer')
    return false, error_summary
  end
end

---Sources only plugin configuration files
---@param config_root string Root directory of the neovim config
---@return boolean success True if sourcing was successful
---@return string? error Error message if sourcing fails
local function source_plugins_only(config_root)
  local options = {
    enable_plugins = true,
    enable_keybindings = false,
    recursive = false,
  }

  return source_configs(config_root, options)
end

---Sources only keybinding configuration files
---@param config_root string Root directory of the neovim config
---@return boolean success True if sourcing was successful
---@return string? error Error message if sourcing fails
local function source_keybindings_only(config_root)
  local options = {
    enable_plugins = false,
    enable_keybindings = true,
    recursive = false,
  }

  return source_configs(config_root, options)
end

---Gets a list of configuration files that would be sourced
---@param config_root string Root directory of the neovim config
---@param options FileSourcerOptions? Sourcing options
---@return table file_info Information about files that would be sourced
local function list_config_files(config_root, options)
  options = vim.tbl_deep_extend('force', DEFAULT_OPTIONS, options or {})

  local file_info = {
    plugins = {},
    keybindings = {},
  }

  if options.enable_plugins then
    -- Check for plugins.lua
    local plugins_lua = config_root .. '/plugins.lua'
    if vim.fn.filereadable(plugins_lua) == 1 then
      table.insert(file_info.plugins, plugins_lua)
    end

    -- Check plugins directory
    local plugins_dir = config_root .. '/plugins'
    local plugin_files = get_lua_files(plugins_dir, options.recursive)
    for _, file in ipairs(plugin_files) do
      table.insert(file_info.plugins, file)
    end
  end

  if options.enable_keybindings then
    -- Check for keybindings.lua
    local keybindings_lua = config_root .. '/keybindings.lua'
    if vim.fn.filereadable(keybindings_lua) == 1 then
      table.insert(file_info.keybindings, keybindings_lua)
    end

    -- Check keybindings directory
    local keybindings_dir = config_root .. '/keybindings'
    local keybinding_files = get_lua_files(keybindings_dir, options.recursive)
    for _, file in ipairs(keybinding_files) do
      table.insert(file_info.keybindings, file)
    end
  end

  return file_info
end

---Validates that configuration directories are accessible
---@param config_root string Root directory of the neovim config
---@return boolean valid True if directories are valid
---@return string? error Error message if validation fails
local function validate_config_root(config_root)
  if type(config_root) ~= 'string' or config_root == '' then
    return false, 'config_root must be a non-empty string'
  end

  if vim.fn.isdirectory(config_root) == 0 then
    return false, string.format('config_root directory does not exist: %s', config_root)
  end

  return true, nil
end

return {
  source_configs = source_configs,
  source_plugins_only = source_plugins_only,
  source_keybindings_only = source_keybindings_only,
  list_config_files = list_config_files,
  validate_config_root = validate_config_root,
}
