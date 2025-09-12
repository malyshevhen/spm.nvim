local logger = require('spm.lib.logger')
local toml = require('spm.vendor.toml')
local Result = require('spm.lib.error').Result

---Reads and parses a TOML file
---@param content string Path to the TOML file
---@return spm.Result<table> parsed_toml Parsed TOML content
local function parse(content)
  logger.debug('Parsing TOML content', 'TomlParser')
  if not content or type(content) ~= 'string' then
    return Result.err(string.format('Cannot parse TOML.'))
  end

  local success, result = pcall(toml.parse, content)
  if not success or type(result) ~= 'table' or next(result) == nil then
    logger.error(string.format('Cannot parse TOML: %s', result), 'TomlParser')
    return Result.err(string.format('Cannot parse TOML: %s', result))
  end

  logger.debug('Successfully parsed TOML content', 'TomlParser')
  return Result.ok(result)
end

---Encodes a Lua table to TOML format (using vendor library)
---@param value table The table to encode
---@return spm.Result<string>
local function encode(value)
  logger.debug('Encoding table to TOML', 'TomlParser')
  if type(value) ~= 'table' then
    return Result.err('Input must be a table')
  end

  local success, result = pcall(toml.encode, value)
  if not success then
    logger.error(string.format('TOML encoding failed: %s', result), 'TomlParser')
    return Result.err(string.format('TOML encoding failed: %s', result))
  end

  logger.debug('Successfully encoded table to TOML', 'TomlParser')
  return Result.ok(result)
end

return {
  parse = parse,
  encode = encode,
}