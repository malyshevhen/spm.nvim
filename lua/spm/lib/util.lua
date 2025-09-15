--- Module providing utility functions
---
--- This module provides utility functions for working with the plugin manager.
---@module 'spm.lib.util'
local util = {}

--- Calls a function in protected mode and returns its result or an error.
-- This pattern ensures the program does not crash on an error.
---@generic T
---@param func     fun(...): T The function to call.
---@param ...      any The arguments to pass to the function.
---@return T result The first return value of the function if successful, otherwise nil.
---@return string? error Nil if successful, otherwise the error message string.
function util.safe_call(func, ...)
  local success, result_or_error = pcall(func, ...)
  if success then
    -- We return the first result and nil for the error.
    return result_or_error, nil
  else
    -- We return nil for the result and the error message.
    return nil, result_or_error
  end
end

return util
