local toml = require('spm.vendor.toml')
local logger = require('spm.logger')

---Safely parses TOML content using the vendor toml.lua library
---@param content string The TOML content to parse
---@return table? parsed The parsed TOML data
---@return string? error Error message if parsing failed
local function safe_parse(content)
  local success, result = pcall(toml.parse, content)
  if not success then
    return nil, string.format('TOML parsing failed: %s', result)
  end
  return result, nil
end

---Parses TOML content string
---@param content string The TOML content to parse
---@return table parsed The parsed TOML data
local function parse(content)
  if type(content) ~= 'string' then
    error('TOML content must be a string')
  end

  if content == '' then
    return {}
  end

  local parsed, error_msg = safe_parse(content)
  if not parsed then
    error(error_msg)
  end

  logger.debug('Successfully parsed TOML content', 'TomlParser')
  return parsed
end

---Reads and parses a TOML file
---@param filepath string Path to the TOML file
---@return table parsed The parsed TOML data
local function parse_file(filepath)
  if type(filepath) ~= 'string' then
    error('File path must be a string')
  end

  -- Check if file exists and is readable
  if vim.fn.filereadable(filepath) == 0 then
    error(string.format('Cannot read file: %s', filepath))
  end

  -- Read file content
  local file = io.open(filepath, 'r')
  if not file then
    error(string.format('Cannot open file: %s', filepath))
  end

  local content = file:read('*all')
  file:close()

  if not content then
    error(string.format('Failed to read content from file: %s', filepath))
  end

  logger.debug(string.format('Read %d bytes from %s', #content, filepath), 'TomlParser')

  -- Parse the content
  local parsed, error_msg = safe_parse(content)
  if not parsed then
    error(string.format('Failed to parse %s: %s', filepath, error_msg))
  end

  logger.debug(string.format('Successfully parsed TOML file: %s', filepath), 'TomlParser')
  return parsed
end

---Parses plugins.toml specifically and returns a PluginConfig
---@param filepath string Path to the plugins.toml file
---@return PluginConfig config The parsed plugin configuration
local function parse_plugins_toml(filepath)
  logger.debug(string.format('Parsing plugins.toml: %s', filepath), 'TomlParser')

  local data = parse_file(filepath)

  -- Validate that we have a plugins section
  if not data.plugins then
    error(string.format('plugins.toml must contain a [[plugins]] section. File: %s', filepath))
  end

  if type(data.plugins) ~= 'table' then
    error(string.format('plugins section must be an array of tables. File: %s', filepath))
  end

  if #data.plugins == 0 then
    logger.warn('No plugins defined in plugins.toml', 'TomlParser')
  end

  logger.info(
    string.format('Parsed %d plugin definitions from %s', #data.plugins, filepath),
    'TomlParser'
  )

  return {
    plugins = data.plugins,
    language_servers = data.language_servers,
    filetypes = data.filetypes,
  }
end

---Validates TOML content without parsing it fully (useful for syntax checking)
---@param content string The TOML content to validate
---@return boolean valid True if the TOML content is valid
---@return string? error Error message if validation failed
local function validate(content)
  if type(content) ~= 'string' then
    return false, 'TOML content must be a string'
  end

  if content == '' then
    return true, nil
  end

  local _, error_msg = safe_parse(content)
  if error_msg then
    return false, error_msg
  end

  return true, nil
end

---Validates a TOML file without parsing it fully
---@param filepath string Path to the TOML file
---@return boolean valid True if the TOML file is valid
---@return string? error Error message if validation failed
local function validate_file(filepath)
  if type(filepath) ~= 'string' then
    return false, 'File path must be a string'
  end

  if vim.fn.filereadable(filepath) == 0 then
    return false, string.format('Cannot read file: %s', filepath)
  end

  local file = io.open(filepath, 'r')
  if not file then
    return false, string.format('Cannot open file: %s', filepath)
  end

  local content = file:read('*all')
  file:close()

  if not content then
    return false, string.format('Failed to read content from file: %s', filepath)
  end

  return validate(content)
end

---Encodes a Lua table to TOML format (using vendor library)
---@param tbl table The table to encode
---@return string toml_content The TOML representation
local function encode(tbl)
  if type(tbl) ~= 'table' then
    error('Input must be a table')
  end

  local success, result = pcall(toml.encode, tbl)
  if not success then
    error(string.format('TOML encoding failed: %s', result))
  end

  logger.debug('Successfully encoded table to TOML', 'TomlParser')
  return result
end

---Gets information about the TOML library being used
---@return table info Information about the TOML parser
local function get_info()
  return {
    library = 'vendor/toml.lua',
    version = toml.version or 'unknown',
    strict_mode = toml.strict,
  }
end

---Sets strict mode for TOML parsing (if supported by vendor library)
---@param strict boolean Whether to enable strict mode
local function set_strict_mode(strict)
  if type(strict) ~= 'boolean' then
    error('Strict mode must be a boolean')
  end

  if toml.strict ~= nil then
    toml.strict = strict
    logger.debug(string.format('Set TOML strict mode to %s', tostring(strict)), 'TomlParser')
  else
    logger.warn('TOML library does not support strict mode configuration', 'TomlParser')
  end
end

return {
  parse_plugins_toml = parse_plugins_toml,
  parse_file = parse_file,
  encode = encode,
}
