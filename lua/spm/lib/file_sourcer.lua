local logger = require('spm.lib.logger')
local Result = require('spm.lib.error').Result

---@class FileSourcerOptions
---@field recursive boolean Whether to source directories recursively (not recommended)

---@class SourceResult
---@field success boolean Whether the operation was successful
---@field files_sourced number Number of files successfully sourced
---@field errors table[] List of errors encountered

---Safely sources a single Lua file
---@param filepath string Path to the Lua file to source
---@return Result<nil>
local function source_lua_file(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    return Result.err(string.format('File not readable: %s', filepath))
  end

  local success, err = pcall(dofile, filepath)
  if not success then return Result.err(string.format('Error sourcing %s: %s', filepath, err)) end

  return Result.ok(nil)
end

---Gets all Lua files in a directory
---@param dirpath string Path to the directory
---@param recursive boolean Whether to search recursively
---@return string[] filepaths List of Lua file paths found
local function get_lua_files(dirpath, recursive)
  if vim.fn.isdirectory(dirpath) == 0 then return {} end

  local pattern = recursive and '**/*.lua' or '*.lua'
  local glob_pattern = dirpath .. '/' .. pattern

  return vim.fn.glob(glob_pattern, false, true)
end

---Sources all Lua files in a directory
---@param dirpath string Path to the directory
---@param options FileSourcerOptions Sourcing options
---@return Result<SourceResult>
local function source_directory(dirpath, options)
  local result = {
    success = true,
    files_sourced = 0,
    errors = {},
  }

  local files = get_lua_files(dirpath, options.recursive)

  for _, filepath in ipairs(files) do
    local source_result = source_lua_file(filepath)
    if source_result:is_ok() then
      result.files_sourced = result.files_sourced + 1
      logger.debug(string.format('Sourced: %s', filepath), 'FileSourcer')
    else
      result.success = false
      table.insert(result.errors, {
        file = filepath,
        error = source_result.error,
      })
      logger.error(source_result.error.message or 'Unknown error', 'FileSourcer')
    end
  end

  if result.success then
    return Result.ok(result)
  else
    return Result.err(result)
  end
end

return {
  source_lua_file = source_lua_file,
  get_lua_files = get_lua_files,
  source_directory = source_directory,
}
