local Result = require('spm.error').Result

---Generates a SHA256 hash for the given content
---@param content string The content to hash
---@return Result<string>
local function generate_hash(content)
  if type(content) ~= 'string' then return Result.err('Content must be a string') end

  local success, hash = pcall(vim.fn.sha256, content)
  if not success then return Result.err('Failed to generate hash') end

  return Result.ok(hash)
end

return {
  generate_hash = generate_hash,
}
