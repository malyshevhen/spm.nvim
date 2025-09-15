--- Module for sourcing files
---
--- This module provides functions for sourcing files from a directory.
--- It is used by the plugin manager to source configuration files.
---
--- The `source_directory` function is the main entry point for the file
--- sourcer. It takes a directory path and an optional options table as
--- arguments. The function returns a table with two fields:
--- - `success`: Whether the operation was successful
--- - `errors`: A list of errors encountered during the operation
---
--- The `get_lua_files` function returns a list of Lua files in a directory.
--- It takes a directory path and an optional boolean flag as arguments.
--- The flag indicates whether to search recursively for Lua files.
---
--- The `source_lua_file` function sources a Lua file. It takes a file path
--- as an argument and returns a boolean indicating whether the operation
--- was successful.
---@module 'spm.lib.file_sourcer'
local file_sourcer = {}

local logger = require('spm.lib.logger')

---@class spm.FileSourcerOptions
---@field recursive boolean Whether to source directories recursively (not recommended)

---@class spm.SourceResult
---@field success boolean Whether the operation was successful
---@field files_sourced number Number of files successfully sourced
---@field errors table[] List of errors encountered

---Gets all Lua files in a directory
---@param dirpath string Path to the directory
---@param recursive boolean Whether to search recursively
---@return string[] filepaths List of Lua file paths found
function file_sourcer.get_lua_files(dirpath, recursive)
  if vim.fn.isdirectory(dirpath) == 0 then return {} end

  local pattern = recursive and '**/*.lua' or '*.lua'
  local glob_pattern = dirpath .. '/' .. pattern

  return vim.fn.glob(glob_pattern, false, true)
end

---Safely sources a single Lua file
---@param filepath string Path to the Lua file to source
---@return boolean?, string?
function file_sourcer.source_lua_file(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    return nil, string.format('File not readable: %s', filepath)
  end

  local success, err = pcall(dofile, filepath)
  if not success then return nil, string.format('Error sourcing %s: %s', filepath, err) end

  return true
end

---Sources all Lua files in a directory
---@param dirpath string Path to the directory
---@param options spm.FileSourcerOptions Sourcing options
---@return table?, string?
function file_sourcer:source_directory(dirpath, options)
  local result = {
    success = true,
    files_sourced = 0,
    errors = {},
  }

  local files = self.get_lua_files(dirpath, options.recursive)

  for _, filepath in ipairs(files) do
    local ok, err = self.source_lua_file(filepath)
    if ok then
      result.files_sourced = result.files_sourced + 1
      logger.debug(string.format('Sourced: %s', filepath), 'FileSourcer')
    else
      result.success = false
      table.insert(result.errors, {
        file = filepath,
        error = err,
      })
      logger.error(err or 'FileSourcer failed', 'FileSourcer')
    end
  end

  if result.success then
    return result
  else
    return nil, 'Some files failed to source'
  end
end

return file_sourcer
