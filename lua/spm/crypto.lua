---@class Crypto
local M = {}

---Generates a SHA256 hash for the given content
---@param content string The content to hash
---@return string? hash The SHA256 hash, or nil if hashing fails
function M.generate_hash(content)
  if type(content) ~= 'string' then
    return nil
  end

  local success, hash = pcall(vim.fn.sha256, content)
  if not success then
    return nil
  end

  return hash
end

return M
