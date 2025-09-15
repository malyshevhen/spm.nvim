--- Module for cryptographic operations
---
--- This module provides functions for generating hashes and checking hashes.
---@module 'spm.lib.crypto'
local crypto = {}

local safe_call = require('spm.lib.util').safe_call

---Generates a SHA256 hash for the given content
---@param content string The content to hash
---@return string?, string?
function crypto.generate_hash(content)
  if type(content) ~= 'string' then return nil, 'Content must be a string' end

  local hash, err = safe_call(vim.fn.sha256, content)
  if err then return nil, 'Failed to generate hash' end

  return hash
end

---Checks if the given hash matches the content
---@param content string The content to check
---@param hash string The hash to compare
---@return boolean, string?
function crypto.check_hash(content, hash)
  if type(content) ~= 'string' then return false, 'Content must be a string' end
  if type(hash) ~= 'string' then return false, 'Hash must be a string' end

  local ok, err = safe_call(vim.fn.sha256, content)
  if err then return false, 'Failed to generate hash' end

  return hash == ok
end

return crypto
