---@class LockManager
local M = {}

local logger = require('spm.logger')

---@class LockManagerDependencies
---@field toml_parser TomlParser
---@field crypto Crypto

---@class LockManager
---@field dependencies LockManagerDependencies
---@field logger table
local LockManager = {}
LockManager.__index = LockManager

---Creates a new lock manager instance
---@param dependencies LockManagerDependencies
---@return LockManager
function M.new(dependencies)
  if not dependencies or not dependencies.toml_parser or not dependencies.crypto then
    error('LockManager requires toml_parser and crypto dependencies')
  end

  return setmetatable({
    dependencies = dependencies,
    logger = logger.create_context('LockManager'),
  }, LockManager)
end

---Reads and parses the lock file
---@param lock_file_path string
---@return table? lock_data
---@return string? error
function LockManager:read(lock_file_path)
  if vim.fn.filereadable(lock_file_path) == 0 then
    self.logger.info('Lock file not found at: ' .. lock_file_path)
    return nil
  end

  local success, data = pcall(self.dependencies.toml_parser.parse_file, lock_file_path)
  if not success then
    local err = 'Failed to parse lock file: ' .. tostring(data)
    self.logger.error(err)
    return nil, err
  end

  return data
end

---Writes data to the lock file
---@param lock_file_path string
---@param lock_data table
---@return boolean success
---@return string? error
function LockManager:write(lock_file_path, lock_data)
  local ok, result = pcall(self.dependencies.toml_parser.encode, lock_data)
  if not ok then
    local error_msg = 'Failed to encode lock data: ' .. tostring(result)
    self.logger.error(error_msg)
    return false, error_msg
  end

  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(lock_file_path, ':h')
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end

  local file, open_err = io.open(lock_file_path, 'w')
  if not file then
    local error_msg = 'Failed to open lock file for writing: ' .. tostring(open_err)
    self.logger.error(error_msg)
    return false, error_msg
  end

  file:write(result)
  file:close()
  self.logger.info('Lock file updated at: ' .. lock_file_path)
  return true
end

---Checks if the lock file is stale by comparing hashes
---@param plugins_toml_content string
---@param lock_data table?
---@return boolean is_stale
function LockManager:is_stale(plugins_toml_content, lock_data)
  if not lock_data or not lock_data.hash then
    self.logger.info('Lock file is stale: no lock data or hash found.')
    return true
  end

  local new_hash = self.dependencies.crypto.generate_hash(plugins_toml_content)
  if not new_hash then
    self.logger.error('Failed to generate hash for plugins.toml')
    return true -- Treat as stale if hashing fails
  end

  if new_hash ~= lock_data.hash then
    self.logger.info('Lock file is stale: plugins.toml has changed.')
    return true
  end

  self.logger.info('Lock file is up to date.')
  return false
end

return M
