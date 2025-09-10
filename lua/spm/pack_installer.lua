local logger = require('spm.logger')

---@class PackInstallerOptions
---@field confirm boolean Whether to ask user to confirm installation
---@field load boolean Whether to load plugins after installation

---Default options for pack installation
---@type PackInstallerOptions
local DEFAULT_OPTIONS = {
  confirm = false,
  load = true,
}

---Converts a plugin spec to vim.pack format
---@param plugin PluginSpec The plugin to convert
---@return table pack_spec The vim.pack specification
local function to_pack_spec(plugin)
  local pack_spec = {
    src = plugin.src,
  }

  -- Add name if specified
  if plugin.name then
    pack_spec.name = plugin.name
  end

  -- Add version if specified
  if plugin.version then
    pack_spec.version = plugin.version
  end

  return pack_spec
end

---Validates that vim.pack is available
---@return boolean available True if vim.pack is available
---@return string? error Error message if not available
local function validate_vim_pack()
  if not vim.pack then
    return false, 'vim.pack is not available - requires Neovim 0.12+'
  end

  if type(vim.pack.add) ~= 'function' then
    return false, 'vim.pack.add is not available or not a function'
  end

  return true, nil
end

---Fallback installation using git clone for older Neovim versions
---@param plugins PluginSpec[] List of plugins to install
---@return boolean success True if installation was successful
---@return string? error Error message if installation fails
local function install_with_git(plugins)
  local pack_dir = vim.fn.stdpath('data') .. '/site/pack/spm/start'

  -- Create pack directory if it doesn't exist
  vim.fn.mkdir(pack_dir, 'p')

  local failed_plugins = {}

  for _, plugin in ipairs(plugins) do
    local plugin_name = plugin.name or plugin.src:match('([^/]+)$'):gsub('%.git$', '')
    local install_path = pack_dir .. '/' .. plugin_name

    -- Skip if already installed
    if vim.fn.isdirectory(install_path) == 0 then
      local cmd = string.format('git clone --depth=1 %s %s', plugin.src, install_path)
      local result = vim.fn.system(cmd)

      if vim.v.shell_error ~= 0 then
        table.insert(failed_plugins, {
          name = plugin_name,
          src = plugin.src,
          error = result,
        })
      else
        logger.debug(string.format('Installed plugin: %s', plugin_name), 'PackInstaller')
      end
    else
      logger.debug(string.format('Plugin already exists: %s', plugin_name), 'PackInstaller')
    end
  end

  if #failed_plugins > 0 then
    local error_msg = string.format('Failed to install %d plugins', #failed_plugins)
    for _, failure in ipairs(failed_plugins) do
      logger.error(
        string.format('Failed to install %s: %s', failure.name, failure.error),
        'PackInstaller'
      )
    end
    return false, error_msg
  end

  return true, nil
end

---Installs plugins using vim.pack.add or git fallback
---@param plugins PluginSpec[] List of plugins to install
---@param options PackInstallerOptions? Installation options
---@return boolean success True if installation was successful
---@return string? error Error message if installation fails
local function install(plugins, options)
  if not plugins or #plugins == 0 then
    return true, nil -- Nothing to install is considered success
  end

  -- Check vim.pack availability and use fallback if needed
  local available, pack_error = validate_vim_pack()
  if not available then
    logger.warn(
      'vim.pack not available, using git fallback: ' .. (pack_error or 'unknown error'),
      'PackInstaller'
    )
    return install_with_git(plugins)
  end

  -- Merge options with defaults for vim.pack
  options = vim.tbl_deep_extend('force', DEFAULT_OPTIONS, options or {})

  -- Convert all plugins to vim.pack format
  local pack_specs = {}
  for _, plugin in ipairs(plugins) do
    local pack_spec = to_pack_spec(plugin)
    table.insert(pack_specs, pack_spec)
  end

  -- Install all plugins in one call
  local success, err = pcall(vim.pack.add, pack_specs, options)
  if not success then
    logger.warn('vim.pack.add failed, falling back to git: ' .. tostring(err), 'PackInstaller')
    return install_with_git(plugins)
  end

  return true, nil
end

---Gets information about installed plugins
---@param plugin_names string[]? List of plugin names to get info for (nil for all)
---@return table[]? plugin_info List of plugin information
---@return string? error Error message if operation fails
local function get_info(plugin_names)
  local available, error_msg = validate_vim_pack()
  if not available then
    return nil, error_msg
  end

  local success, result = pcall(vim.pack.get, plugin_names)
  if not success then
    return nil, string.format('vim.pack.get failed: %s', result)
  end

  return result, nil
end

---Updates plugins to their latest versions
---@param plugin_names string[]? List of plugin names to update (nil for all active)
---@param force boolean? Whether to skip confirmation and update immediately
---@return boolean success True if update was successful
---@return string? error Error message if update fails
local function update(plugin_names, force)
  local available, error_msg = validate_vim_pack()
  if not available then
    return false, error_msg
  end

  local options = {
    force = force or false,
  }

  local success, err = pcall(vim.pack.update, plugin_names, options)
  if not success then
    return false, string.format('vim.pack.update failed: %s', err)
  end

  return true, nil
end

---Removes plugins from disk
---@param plugin_names string[] List of plugin names to remove
---@return boolean success True if removal was successful
---@return string? error Error message if removal fails
local function remove(plugin_names)
  if not plugin_names or #plugin_names == 0 then
    return true, nil -- Nothing to remove is considered success
  end

  local available, error_msg = validate_vim_pack()
  if not available then
    return false, error_msg
  end

  local success, err = pcall(vim.pack.del, plugin_names)
  if not success then
    return false, string.format('vim.pack.del failed: %s', err)
  end

  return true, nil
end

---Checks if vim.pack is available and working
---@return boolean available True if vim.pack is available
---@return string? error Error message if not available
local function check_availability()
  return validate_vim_pack()
end

return {
  install = install,
  get_info = get_info,
  update = update,
  remove = remove,
  check_availability = check_availability,
}
