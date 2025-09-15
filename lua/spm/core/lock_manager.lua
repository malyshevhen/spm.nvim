--- Module for managing the lock file
---
--- The lock file is a TOML file that contains information about the plugins
--- and their versions. It is used to ensure that the plugins installed by
--- the plugin manager are compatible with the current configuration.
---
--- The lock file is read and written using the `spm.lib.toml` module.
---
--- The lock file is stored in the `spm.config.lock_file_path` directory.
---
--- The lock file is updated when the plugin manager is run with the
--- `--update-lock` flag. This flag is used to update the lock file when
--- the configuration has changed.
---
--- The lock file is also updated when the plugin manager is run with the
--- `--install` flag. This flag is used to install the plugins specified in
--- the configuration.
---
--- The lock file is also updated when the plugin manager is run with the
--- `--debug` flag. This flag is used to show the flattened plugins without
--- installing them.
---
--- The lock file is also updated when the plugin manager is run with the
--- `--debug` flag. This flag is used to show the flattened plugins without
--- installing them.
---@module 'spm.core.lock_manager'
local lock_manager = {}

local crypto = require('spm.lib.crypto')
local fs = require('spm.lib.fs')
local logger = require('spm.lib.logger')
local toml = require('spm.lib.toml')

---Reads and parses the lock file
---@param lock_file_path string
---@return table?, string?
function lock_manager.read(lock_file_path)
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

  return toml.parse(content)
end

---Writes data to the lock file
---@param lock_file_path string
---@param lock_data table
---@return boolean?, string?
function lock_manager.write(lock_file_path, lock_data)
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

  local encoded_data, err = toml.encode(lock_data)
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
function lock_manager.is_stale(plugins_toml_content, lock_data)
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

return lock_manager
