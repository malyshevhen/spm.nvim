local crypto = require('spm.lib.crypto')
local fs = require('spm.lib.fs')
local logger = require('spm.lib.logger')
local toml_parser = require('spm.lib.toml_parser')

---Reads and parses the lock file
---@param lock_file_path string
---@return table?, string?
local function read(lock_file_path)
  logger.debug(string.format('Reading lock file: %s', lock_file_path), 'LockManager')
  if vim.fn.filereadable(lock_file_path) ~= 1 then
    logger.debug('Lock file not found', 'LockManager')
    return {}
  end

  local content, err = fs.read_file(lock_file_path)
  if err or not content then return nil, err end

  if content == '' then
    logger.debug('Lock file is empty', 'LockManager')
    return {}
  end

  return toml_parser.parse(content)
end

---Writes data to the lock file
---@param lock_file_path string
---@param lock_data table
---@return boolean?, string?
local function write(lock_file_path, lock_data)
  -- Create the directory if it doesn't exist
  local dir = vim.fn.fnamemodify(lock_file_path, ':h')
  if vim.fn.isdirectory(dir) == 0 then
    logger.debug(string.format('Creating directory: %s', dir), 'LockManager')
    local success = vim.fn.mkdir(dir, 'p')
    if success == 0 then
      logger.error(string.format('Failed to create directory: %s', dir), 'LockManager')
      return nil, string.format('Failed to create directory: %s', dir)
    end
  end

  -- Check again after creating the directory
  if vim.fn.isdirectory(dir) == 0 then
    logger.error(string.format('Failed to create directory: %s', dir), 'LockManager')
    return nil, string.format('Failed to create directory: %s', dir)
  end

  -- Read the lock data
  logger.debug(string.format('Writing to lock file: %s', lock_file_path), 'LockManager')

  local encoded_data, err = toml_parser.encode(lock_data)
  if err or not encoded_data then
    logger.error('Failed to encode lock data', 'LockManager')
    return nil, err
  end

  -- Write the lock file
  local ok, write_err = fs.write_file(lock_file_path, encoded_data)
  if not ok then return nil, write_err end

  logger.info(string.format('Lock file updated at: %s', lock_file_path), 'LockManager')
  return true
end

---Checks if the lock file is stale by comparing hashes
---@param plugins_toml_content string
---@param lock_data table?
---@return boolean is_stale
local function is_stale(plugins_toml_content, lock_data)
  logger.debug('Checking if lock file is stale', 'LockManager')
  if not lock_data or not lock_data.hash then
    logger.info('Lock file is stale: no lock data or hash found.', 'LockManager')
    return true
  end

  local new_hash, err = crypto.generate_hash(plugins_toml_content)
  if err then
    logger.error('Failed to generate hash for plugins.toml', 'LockManager')
    return true -- Treat as stale if hashing fails
  end

  if new_hash ~= lock_data.hash then
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
