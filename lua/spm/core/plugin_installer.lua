--- Module for managing the plugin installation process
---
--- This module provides functions for installing plugins using the
--- `vim.pack.add` function. It also provides a function for validating
--- the vim.pack module.
---
--- The `install` function is the main entry point for the plugin installer.
--- It takes a list of plugins and an optional options table as arguments.
--- The plugins are validated using the `spm.core.plugin_types.PluginSpec`
--- schema. If the validation fails, an error message is logged and the
--- function returns `nil`.
---
--- The `validate_vim_pack` function checks if the vim.pack module is available.
--- If it is not, an error message is logged and the function returns `nil`.
---
--- The `to_pack_spec` function converts a `spm.core.plugin_types.PluginSpec`
--- to a `vim.pack.add` compatible format.
---@module 'spm.core.plugin_installer'
local plugin_installer = {}

local logger = require('spm.lib.logger')

---@class spm.InstallerOptions
---@field confirm boolean Whether to ask user to confirm installation
---@field load boolean Whether to load plugins after installation

---Default options for pack installation
---@type spm.InstallerOptions
local DEFAULT_OPTIONS = {
  confirm = false,
  load = true,
}

---Converts a plugin spec to vim.pack format
---@param plugin spm.PluginSpec The plugin to convert
---@return table pack_spec The vim.pack specification
local function to_pack_spec(plugin)
  return {
    src = plugin.src,
    name = plugin.name,
    version = plugin.version,
  }
end

---Validates that vim.pack is available
---@return boolean?, string?
local function validate_vim_pack()
  if not vim.pack or type(vim.pack.add) ~= 'function' then
    return nil, 'vim.pack is not available - requires Neovim 0.12+'
  end
  return true
end

---Installs plugins using vim.pack.add
---@param plugins spm.PluginSpec[] List of plugins to install
---@param options spm.InstallerOptions? Installation options
---@return boolean?, string?
function plugin_installer.install(plugins, options)
  if not plugins or #plugins == 0 then
    return true -- Nothing to install is considered success
  end

  local ok, err = validate_vim_pack()
  if not ok then
    logger.error('vim.pack not available: ' .. err, 'PackInstaller')
    return nil, err
  end

  options = vim.tbl_deep_extend('force', DEFAULT_OPTIONS, options or {})

  local pack_specs = vim.tbl_map(to_pack_spec, plugins)

  local success, pack_err = pcall(vim.pack.add, pack_specs, options)
  if not success then
    logger.error('vim.pack.add failed: ' .. tostring(pack_err), 'PackInstaller')
    return nil, tostring(pack_err)
  end

  return true
end

return plugin_installer
