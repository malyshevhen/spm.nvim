---@class SimpleKeymap
local M = {}

---@class KeymapSpec
---@field map string The keymap key combination
---@field cmd string|function The command to execute
---@field desc string? Description for the keymap
---@field mode string|string[]? Mode(s) for the keymap (default: 'n')
---@field ft string? Filetype restriction
---@field opts table? Additional options for vim.keymap.set

---Validates a keymap specification
---@param keymap KeymapSpec The keymap to validate
---@return boolean valid True if the keymap is valid
---@return string? error_msg Error message if validation fails
local function validate_keymap(keymap)
  if type(keymap) ~= 'table' then
    return false, 'Keymap must be a table'
  end

  if not keymap.map or type(keymap.map) ~= 'string' then
    return false, "Keymap must have a 'map' field of type string"
  end

  if not keymap.cmd or (type(keymap.cmd) ~= 'string' and type(keymap.cmd) ~= 'function') then
    return false, "Keymap must have a 'cmd' field of type string or function"
  end

  if keymap.desc and type(keymap.desc) ~= 'string' then
    return false, "Keymap 'desc' must be a string"
  end

  if keymap.mode then
    if type(keymap.mode) == 'string' then
      -- Single mode is ok
    elseif type(keymap.mode) == 'table' then
      -- Array of modes - validate each
      for _, mode in ipairs(keymap.mode) do
        if type(mode) ~= 'string' then
          return false, "All modes in 'mode' array must be strings"
        end
      end
    else
      return false, "Keymap 'mode' must be a string or array of strings"
    end
  end

  if keymap.ft and type(keymap.ft) ~= 'string' then
    return false, "Keymap 'ft' must be a string"
  end

  if keymap.opts and type(keymap.opts) ~= 'table' then
    return false, "Keymap 'opts' must be a table"
  end

  return true, nil
end

---Sets a single keymap using vim.keymap.set
---@param keymap KeymapSpec The keymap to set
---@return boolean success True if the keymap was set successfully
local function set_single_keymap(keymap)
  local valid, err = validate_keymap(keymap)
  if not valid then
    vim.notify(string.format('Invalid keymap: %s', err), vim.log.levels.WARN)
    return false
  end

  -- Default mode to normal if not specified
  -- vim.keymap.set accepts both string and string[] for mode
  local mode = keymap.mode or 'n'

  -- Build options table
  local opts = keymap.opts or {}
  if keymap.desc then
    opts.desc = keymap.desc
  end

  -- Handle filetype-specific keymaps
  if keymap.ft then
    -- Create an auto command for filetype-specific keymaps
    vim.api.nvim_create_autocmd('FileType', {
      pattern = keymap.ft,
      callback = function(args)
        vim.keymap.set(
          mode,
          keymap.map,
          keymap.cmd,
          vim.tbl_extend('force', opts, { buffer = args.buf })
        )
      end,
      desc = string.format('Set keymap %s for filetype %s', keymap.map, keymap.ft),
    })
  else
    -- Set global keymap immediately
    vim.keymap.set(mode, keymap.map, keymap.cmd, opts)
  end

  return true
end

---Maps keymaps immediately using vim.keymap.set
---@param keymaps KeymapSpec|KeymapSpec[] Single keymap or array of keymaps
---@return number success_count Number of successfully set keymaps
---@return number total_count Total number of keymaps attempted
function M.map(keymaps)
  local success_count = 0
  local total_count = 0

  -- Handle single keymap or array of keymaps
  if keymaps.map then
    -- Single keymap (has .map field)
    total_count = 1
    if set_single_keymap(keymaps) then
      success_count = 1
    end
  else
    -- Array of keymaps
    for _, keymap in ipairs(keymaps) do
      total_count = total_count + 1
      if set_single_keymap(keymap) then
        success_count = success_count + 1
      end
    end
  end

  return success_count, total_count
end

return M
