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
local logger = require('spm.lib.logger')

---@class spm.fs
local fs = {}

---@param path string
---@return spm.Result<nil>
function fs.delete_file(path)
  logger.debug(string.format('Deleting file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then
    return Result.err('Invalid path')
  end

  ---Helper function for deleting a file
  ---@return fun(): nil
  local function delete_file_func()
    return function()
      local success, err = vim.uv.fs_unlink(path)
      if not success then
        error(err)
      end

      return nil
    end
  end

  return Result.try(delete_file_func()):map_err(
    function(err) return string.format('Failed to delete file: %s; %s', path, tostring(err)) end
  )
end

---@param path string
---@return spm.Result<nil>
function fs.mkdir(path)
  logger.debug(string.format('Creating directory: %s', path), 'fs')
  if not path or type(path) ~= 'string' then
    return Result.err('Invalid path')
  end

  ---Helper function for creating a directory
  ---@return fun(): nil
  local function mkdir_func()
    return function()
      local success, err = vim.uv.fs_mkdir(path, 448)
      if not success then
        error(err)
      end

      return nil
    end
  end

  return Result.try(mkdir_func()):map_err(
    function(err) return string.format('Failed to create directory: %s; %s', path, tostring(err)) end
  )
end

---@param path string
---@return spm.Result<nil>
function fs.rmdir(path)
  logger.debug(string.format('Removing directory: %s', path), 'fs')
  if not path or type(path) ~= 'string' then
    return Result.err('Invalid path')
  end

  ---Helper function for removing a directory
  ---@return fun(): nil
  local function rmdir_func()
    return function()
      local success, err = vim.uv.fs_rmdir(path)
      if not success then
        error(err)
      end

      return nil
    end
  end
  return Result.try(rmdir_func()):map_err(
    function(err) return string.format('Failed to remove directory: %s; %s', path, tostring(err)) end
  )
end

---@param path string
---@param content string
---@return spm.Result<nil>
function fs.write_file(path, content)
  logger.debug(string.format('Writing to file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then
    return Result.err('Invalid path')
  end

  if not content or type(content) ~= 'string' then
    return Result.err('Invalid content')
  end

  ---Helper function for writing a file
  ---@return fun(): nil
  local function write_file_func()
    return function()
      local fd = assert(vim.uv.fs_open(path, 'w', 438))
      local _ = assert(vim.uv.fs_write(fd, content))
      return nil
    end
  end

  return Result.try(write_file_func()):map_err(
    function(err) return string.format('Failed to write file: %s; %s', path, tostring(err)) end
  )
end

---@param path string
---@return spm.Result<string>
function fs.read_file(path)
  logger.debug(string.format('Reading file: %s', path), 'fs')
  if not path or type(path) ~= 'string' then
    return Result.err('Invalid path')
  end

  ---Helper function for reading a file
  ---@return fun(): string
  local function read_file_func()
    return function()
      local fd = assert(vim.uv.fs_open(path, 'r', 438))
      local stat = assert(vim.uv.fs_fstat(fd))
      local data = assert(vim.uv.fs_read(fd, stat.size, 0))
      assert(vim.loop.fs_close(fd))
      return data
    end
  end

  return Result.try(read_file_func()):map_err(
    function(err) return string.format('Failed to read file: %s; %s', path, tostring(err)) end
  )
end

return fs
