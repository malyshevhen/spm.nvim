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

local Result = require('spm.lib.error').Result
local Path = require('plenary.path')
local logger = require('spm.lib.logger')

---@class spm.fs
local fs = {}

---@param path string
---@return spm.Result<nil>
function fs.delete_file(path)
  logger.debug(string.format('Deleting file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return Result.err('Invalid path') end

  local p = Path:new(path)
  if not p:exists() then return Result.err('File does not exist') end

  local success, err = pcall(function() return p:rm() end)
  if success then
    return Result.ok(nil)
  else
    return Result.err(string.format('Failed to delete file: %s; %s', path, tostring(err)))
  end
end

---@param path string
---@return spm.Result<nil>
function fs.mkdir(path)
  logger.debug(string.format('Creating directory: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return Result.err('Invalid path') end

  local success, err = pcall(function()
    local ok, uv_err = vim.uv.fs_mkdir(path, 448)
    if not ok then error(uv_err) end
  end)
  if success then
    return Result.ok(nil)
  else
    return Result.err(string.format('Failed to create directory: %s; %s', path, tostring(err)))
  end
end

---@param path string
---@return spm.Result<nil>
function fs.rmdir(path)
  logger.debug(string.format('Removing directory: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return Result.err('Invalid path') end

  local success, err = pcall(function()
    local ok, uv_err = vim.uv.fs_rmdir(path)
    if not ok then error(uv_err) end
  end)
  if success then
    return Result.ok(nil)
  else
    return Result.err(string.format('Failed to remove directory: %s; %s', path, tostring(err)))
  end
end

---@param path string
---@param content string
---@return spm.Result<nil>
function fs.write_file(path, content)
  logger.debug(string.format('Writing to file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return Result.err('Invalid path') end

  if not content or type(content) ~= 'string' then return Result.err('Invalid content') end

  local p = Path:new(path)
  local success, err = pcall(function() return p:write(content, 'w') end)
  if success then
    return Result.ok(nil)
  else
    return Result.err(string.format('Failed to write file: %s; %s', path, tostring(err)))
  end
end

---@param path string
---@return spm.Result<string>
function fs.read_file(path)
  logger.debug(string.format('Reading file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then return Result.err('Invalid path') end

  local p = Path:new(path)
  if not p:exists() then return Result.err('File does not exist') end

  local success, content = pcall(function() return p:read() end)
  if success then
    return Result.ok(content)
  else
    return Result.err(string.format('Failed to read file: %s; %s', path, tostring(content)))
  end
end

return fs
