local logger = require('spm.lib.logger')
local crypto = require('spm.lib.crypto')
local toml_parser = require('spm.lib.toml_parser')
local Result = require('spm.lib.error').Result

---Reads and parses the lock file
---@param lock_file_path string
---@return Result<table>
local function read(lock_file_path)
  if vim.fn.filereadable(lock_file_path) == 0 then
    logger.info('Lock file not found at: ' .. lock_file_path, 'LockManager')
    return Result.ok(nil)
  end

  return toml_parser.parse_file(lock_file_path)
end

---Writes data to the lock file
---@param lock_file_path string
---@param lock_data table
---@return Result<boolean>
local function write(lock_file_path, lock_data)
  local encode_result = toml_parser.encode(lock_data)
  if encode_result:is_err() then return encode_result end

  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(lock_file_path, ':h')
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end

  local file, open_err = io.open(lock_file_path, 'w')
  if not file then
    local error_msg = 'Failed to open lock file for writing: ' .. tostring(open_err)
    logger.error(error_msg, 'LockManager')
    return Result.err(error_msg)
  end

  file:write(encode_result:unwrap())
  file:close()
  logger.info('Lock file updated at: ' .. lock_file_path, 'LockManager')
  return Result.ok(true)
end

---Checks if the lock file is stale by comparing hashes
---@param plugins_toml_content string
---@param lock_data table?
---@return boolean is_stale
local function is_stale(plugins_toml_content, lock_data)
  if not lock_data or not lock_data.hash then
    logger.info('Lock file is stale: no lock data or hash found.', 'LockManager')
    return true
  end

  local new_hash_result = crypto.generate_hash(plugins_toml_content)
  if new_hash_result:is_err() then
    logger.error('Failed to generate hash for plugins.toml', 'LockManager')
    return true -- Treat as stale if hashing fails
  end

  if new_hash_result:unwrap() ~= lock_data.hash then
    logger.info('Lock file is stale: plugins.toml has changed.', 'LockManager')
    return true
  end

  logger.info('Lock file is up to date.', 'LockManager')
  return false
end

return {
  read = read,
  write = write,
  is_stale = is_stale,
}
