--- Module for interacting with the file system
---
--- This module is a thin wrapper around `vim.loop.fs_*` functions. It provides
--- a more idiomatic interface and handles errors in a more user-friendly way.
---
--- Contains only couple of necessary functions for the plugin manager.
---
--- Available functions:
--- - `read_file`: Reads a file
--- - `write_file`: Writes a file
--- - `delete_file`: Deletes a file
--- - `mkdir`: Creates a directory
--- - `rmdir`: Removes a directory
---@module 'spm.lib.fs'
local fs = {}

local logger = require('spm.lib.logger')

---@param path string
---@return boolean
local function file_exists(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
    return true
  end
  return false
end

---@param path string
---@return boolean?, string?
function fs.delete_file(path)
  logger.debug(string.format('Deleting file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return nil, 'Invalid path' end

  if not file_exists(path) then return nil, 'File does not exist' end

  local success, err = pcall(function() return os.remove(path) end)
  if success then
    return true
  else
    return nil, string.format('Failed to delete file: %s; %s', path, tostring(err))
  end
end

---@param path string
---@return boolean?, string?
function fs.mkdir(path)
  logger.debug(string.format('Creating directory: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return nil, 'Invalid path' end

  local success, err = pcall(function()
    local ok, uv_err = vim.uv.fs_mkdir(path, 448)
    if not ok then error(uv_err) end
  end)
  if success then
    return true
  else
    return nil, string.format('Failed to create directory: %s; %s', path, tostring(err))
  end
end

---@param path string
---@return boolean?, string?
function fs.rmdir(path)
  logger.debug(string.format('Removing directory: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return nil, 'Invalid path' end

  local success, err = pcall(function()
    local ok, uv_err = vim.uv.fs_rmdir(path)
    if not ok then error(uv_err) end
  end)
  if success then
    return true
  else
    return nil, string.format('Failed to remove directory: %s; %s', path, tostring(err))
  end
end

---@param path string
---@param content string
---@return boolean?, string?
function fs.write_file(path, content)
  logger.debug(string.format('Writing to file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return nil, 'Invalid path' end

  if not content or type(content) ~= 'string' then return nil, 'Invalid content' end

  local success, err = pcall(function()
    local f = io.open(path, 'w')
    if not f then error('Could not open file for writing') end
    f:write(content)
    f:close()
  end)
  if success then
    return true
  else
    return nil, string.format('Failed to write file: %s; %s', path, tostring(err))
  end
end

---@param path string
---@return string?, string?
function fs.read_file(path)
  logger.debug(string.format('Reading file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return nil, 'Invalid path' end

  if not file_exists(path) then return nil, 'File does not exist' end

  local success, content = pcall(function()
    local f = io.open(path, 'r')
    if not f then error('Could not open file for reading') end
    local data = f:read('*a')
    f:close()
    return data
  end)
  if success then
    return content
  else
    return nil, string.format('Failed to read file: %s; %s', path, tostring(content))
  end
end

return fs
