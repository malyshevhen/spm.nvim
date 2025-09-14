local safe_call = require('spm.lib.util').safe_call

---Generates a SHA256 hash for the given content
---@param content string The content to hash
---@return string?, string?
local function generate_hash(content)
  if type(content) ~= 'string' then return nil, 'Content must be a string' end

  local hash, err = safe_call(vim.fn.sha256, content)
  if err then return nil, 'Failed to generate hash' end

  return hash
end

return {
  generate_hash = generate_hash,
}
