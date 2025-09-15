--- Module for marshalling and unmarshalling TOML data
---
--- This module provides functions for parsing and encoding TOML data.
--- It is used by the plugin manager to read and write the lock file.
---
--- The `parse` function reads and parses a TOML file. It takes a string
--- as an argument and returns a table or an error message.
---
--- The `encode` function encodes a Lua table to TOML format. It takes a
--- table as an argument and returns a string or an error message.
---@module 'spm.lib.toml'
local toml = {}

local encoder = require('spm.lib.toml.encoder')
local logger = require('spm.lib.logger')
local parser = require('spm.lib.toml.parser')
local safe_call = require('spm.lib.util').safe_call

---Reads and parses a TOML file
---
---@param content string Path to the TOML file
---@return table?, string?
function toml.parse(content)
  logger.debug('Parsing TOML content', 'TomlParser')
  if not content or type(content) ~= 'string' then return nil, 'Cannot parse TOML.' end

  local parsed, err = safe_call(parser.parse, content)
  if err then
    local msg = string.format('Cannot parse TOML: %s', err)
    logger.error(msg, 'TomlParser')
    return nil, 'Cannot parse TOML: ' .. err
  end

  if type(parsed) ~= 'table' then return nil, 'TOML content is not a table' end

  logger.debug('Successfully parsed TOML content', 'TomlParser')

  return parsed
end

---Encodes a Lua table to TOML format
---
---@param value table The table to encode
---@return string?, string?
function toml.encode(value)
  logger.debug('Encoding table to TOML', 'TomlParser')
  if type(value) ~= 'table' then return nil, 'Input must be a table' end

  local result, err = safe_call(encoder.encode, value)
  if err then
    logger.error(string.format('TOML encoding failed: %s', err), 'TomlParser')
    return nil, string.format('TOML encoding failed: %s', err)
  end

  logger.debug('Successfully encoded table to TOML', 'TomlParser')
  return result
end

return toml
