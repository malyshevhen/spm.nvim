---@class KeymapSpec
---@field map string The keymap key combination
---@field cmd string|function The command to execute
---@field desc string? Description for the keymap
---@field mode string|table<string>? Mode(s) for the keymap (default: 'n')
---@field ft string? Filetype restriction
---@field opts table? Additional options for vim.keymap.set
local KeymapSpec = {}
KeymapSpec.__index = KeymapSpec

---Validates a keymap specification
---@return boolean valid True if the keymap is valid
---@return string? error_msg Error message if validation fails
function KeymapSpec:validate()
  if type(self) ~= 'table' then return false, 'Keymap must be a table' end

  if not self.map or type(self.map) ~= 'string' then
    return false, "Keymap must have a 'map' field of type string"
  end

  if not self.cmd or (type(self.cmd) ~= 'string' and type(self.cmd) ~= 'function') then
    return false, "Keymap must have a 'cmd' field of type string or function"
  end

  return true, nil
end

---Sets a single keymap using vim.keymap.set
---@param self KeymapSpec The keymap to set
---@return boolean success True if the keymap was set successfully
function KeymapSpec:set_single_keymap()
  local valid, err = self:validate()
  if not valid then
    vim.notify(string.format('Invalid keymap: %s', err), vim.log.levels.WARN)
    return false
  end

  -- Default mode to normal if not specified
  -- vim.keymap.set accepts both string and string[] for mode
  local mode = self.mode or 'n'

  -- Build options table
  local opts = self.opts or {}
  if self.desc then opts.desc = self.desc end

  -- Handle filetype-specific keymaps
  if self.ft then
    -- Create an auto command for filetype-specific keymaps
    vim.api.nvim_create_autocmd('FileType', {
      pattern = self.ft,
      callback = function(args)
        vim.keymap.set(
          mode,
          self.map,
          self.cmd,
          vim.tbl_extend('force', opts, { buffer = args.buf })
        )
      end,
      desc = string.format('Set keymap %s for filetype %s', self.map, self.ft),
    })
  else
    -- Set global keymap immediately
    vim.keymap.set(mode, self.map, self.cmd, opts)
  end

  return true
end

---Maps keymaps immediately using vim.keymap.set
---@param keymaps KeymapSpec|KeymapSpec[] Single keymap or array of keymaps
---@return number success_count Number of successfully set keymaps
---@return number total_count Total number of keymaps attempted
local function map(keymaps)
  if not keymaps then return 0, 0 end

  local keymap_list = type(keymaps) == 'table' and keymaps.map and { keymaps } or keymaps

  local success_count = 0
  for _, keymap in ipairs(keymap_list) do
    setmetatable(keymap, KeymapSpec)
    if keymap:set_single_keymap() then success_count = success_count + 1 end
  end

  return success_count, #keymap_list
end

return {
  map = map,
  KeymapSpec = KeymapSpec,
}
