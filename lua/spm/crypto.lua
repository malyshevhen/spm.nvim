---Generates a SHA256 hash for the given content
---@param content string The content to hash
---@return string? hash The SHA256 hash, or nil if hashing fails
local function generate_hash(content)
  if type(content) ~= 'string' then
    return nil
  end

  local success, hash = pcall(vim.fn.sha256, content)
  if not success then
    return nil
  end

  return hash
end

---Checks if the current Neovim version supports crypto functions
---@return boolean supported True if crypto functions are supported
local function is_supported()
  return type(vim.fn.sha256) == 'function'
end

return {
  generate_hash = generate_hash,
  is_supported = is_supported,
}
