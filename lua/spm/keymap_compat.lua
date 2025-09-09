---@class KeymapCompat
---Compatibility layer for existing K:map interface
local M = {}

local keymap = require('spm.keymap')
local logger = require('spm.logger')

---@class CompatKeymapStore
---Compatibility wrapper that mimics the old K:map interface
local CompatKeymapStore = {}
CompatKeymapStore.__index = CompatKeymapStore

---Creates a new compatibility keymap store
---@return CompatKeymapStore
function CompatKeymapStore.new()
  return setmetatable({}, CompatKeymapStore)
end

---Maps keymaps immediately (compatible with old K:map interface)
---@param keymaps table Single keymap or array of keymaps
---@return CompatKeymapStore self For method chaining
function CompatKeymapStore:map(keymaps)
  if not keymaps then
    logger.warn('K:map called with nil keymaps', 'KeymapCompat')
    return self
  end

  -- Use the simplified keymap system directly
  local success_count, total_count = keymap.map(keymaps)

  if total_count > 0 then
    local level = success_count == total_count and 'debug' or 'warn'
    logger[level](
      string.format('Keymaps: %d/%d successful', success_count, total_count),
      'KeymapCompat'
    )
  end

  return self
end

---Creates and sets up the global compatibility K instance
---@return CompatKeymapStore
function M.setup_global()
  local compat_store = CompatKeymapStore.new()
  _G.K = compat_store

  logger.debug('Global K:map compatibility layer initialized', 'KeymapCompat')
  return compat_store
end

---Gets the global compatibility K instance
---@return CompatKeymapStore?
function M.get_global()
  return _G.K
end

---Ensures the global K compatibility layer is available
---@return CompatKeymapStore
function M.ensure_global()
  if not _G.K or type(_G.K.map) ~= 'function' then
    return M.setup_global()
  end
  return _G.K
end

---Cleans up the global K instance
function M.cleanup_global()
  _G.K = nil
  logger.debug('Global K:map compatibility layer cleaned up', 'KeymapCompat')
end

---Checks if the compatibility layer is active
---@return boolean active True if K:map is available globally
function M.is_active()
  return _G.K ~= nil and type(_G.K.map) == 'function'
end

return M
