local simple_config = require('spm.config.simple_config')

---Creates a debug-enabled configuration
---@param user_config table? User-provided configuration
---@return SimplePMConfig? config The debug configuration
---@return string? error Error message if validation fails
local function create_debug(user_config)
  local config = vim.tbl_deep_extend('force', user_config or {}, { debug_mode = true })
  return simple_config.create(config)
end

---Creates a minimal configuration with only essential settings
---@param plugins_toml_path string? Path to plugins.toml file
---@return SimplePMConfig? config The minimal configuration
---@return string? error Error message if validation fails
local function create_minimal(plugins_toml_path)
  return simple_config.create({
    plugins_toml_path = plugins_toml_path,
    debug_mode = false,
    auto_source_configs = true,
    auto_setup_keymaps = true,
  })
end

return {
  create_debug = create_debug,
  create_minimal = create_minimal,
}
