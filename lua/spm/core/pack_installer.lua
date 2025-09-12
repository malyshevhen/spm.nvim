local logger = require('spm.lib.logger')
local Result = require('spm.lib.error').Result

---@class Installer
local installer = {}

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
---@return Result<nil>
local function validate_vim_pack()
  if not vim.pack or type(vim.pack.add) ~= 'function' then
    return Result.err('vim.pack is not available - requires Neovim 0.12+')
  end
  return Result.ok(nil)
end

---Installs plugins using vim.pack.add
---@param plugins PluginSpec[] List of plugins to install
---@param options PackInstallerOptions? Installation options
---@return Result<nil>
local function install(plugins, options)
  if not plugins or #plugins == 0 then
    return Result.ok(nil) -- Nothing to install is considered success
  end

  local validation_result = validate_vim_pack()
  if validation_result:is_err() then
    logger.error('vim.pack not available: ' .. validation_result.error.message, 'PackInstaller')
    return validation_result
  end

  options = vim.tbl_deep_extend('force', DEFAULT_OPTIONS, options or {})

  local pack_specs = vim.tbl_map(to_pack_spec, plugins)

  local success, err = pcall(vim.pack.add, pack_specs, options)
  if not success then
    logger.error('vim.pack.add failed: ' .. tostring(err), 'PackInstaller')
    return Result.err(tostring(err))
  end

  return Result.ok(nil)
end

-- return {
--   install = install,
-- }

return setmetatable(installer, {
  __call = function(_, plugins, options) return install(plugins, options) end,
  __index = installer,
})
