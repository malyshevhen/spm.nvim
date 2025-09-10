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
  return {
    src = plugin.src,
    name = plugin.name,
    version = plugin.version,
  }
end

---Validates that vim.pack is available
---@return boolean available True if vim.pack is available
---@return string? error Error message if not available
local function validate_vim_pack()
  if not vim.pack or type(vim.pack.add) ~= 'function' then
    return false, 'vim.pack is not available - requires Neovim 0.12+'
  end
  return true, nil
end

---Installs plugins using vim.pack.add
---@param plugins PluginSpec[] List of plugins to install
---@param options PackInstallerOptions? Installation options
---@return boolean success True if installation was successful
---@return string? error Error message if installation fails
local function install(plugins, options)
  if not plugins or #plugins == 0 then
    return true, nil -- Nothing to install is considered success
  end

  local available, pack_error = validate_vim_pack()
  if not available then
    logger.error('vim.pack not available: ' .. (pack_error or 'unknown error'), 'PackInstaller')
    return false, pack_error
  end

  options = vim.tbl_deep_extend('force', DEFAULT_OPTIONS, options or {})

  local pack_specs = vim.tbl_map(to_pack_spec, plugins)

  local success, err = pcall(vim.pack.add, pack_specs, options)
  if not success then
    logger.error('vim.pack.add failed: ' .. tostring(err), 'PackInstaller')
    return false, tostring(err)
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

  local options = { force = force or false }

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
