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

---Reads and parses a TOML file
---@param filepath string Path to the TOML file
---@return table? parsed The parsed TOML data
---@return string? error Error message if parsing fails
local function parse_file(filepath)
  if type(filepath) ~= 'string' or vim.fn.filereadable(filepath) == 0 then
    return nil, string.format('Cannot read file: %s', filepath)
  end

  local file = io.open(filepath, 'r')
  if not file then
    return nil, string.format('Cannot open file: %s', filepath)
  end

  local content = file:read('*all')
  file:close()

  if not content then
    return nil, string.format('Failed to read content from file: %s', filepath)
  end

  logger.debug(string.format('Read %d bytes from %s', #content, filepath), 'TomlParser')

  return safe_parse(content)
end

---Parses plugins.toml specifically and returns a PluginConfig
---@param filepath string Path to the plugins.toml file
---@return PluginConfig? config The parsed plugin configuration
---@return string? error Error message if parsing fails
local function parse_plugins_toml(filepath)
  logger.debug(string.format('Parsing plugins.toml: %s', filepath), 'TomlParser')

  local data, err = parse_file(filepath)
  if not data then
    return nil, err
  end

  if not data.plugins or type(data.plugins) ~= 'table' then
    return nil, string.format('plugins.toml must contain a [[plugins]] section. File: %s', filepath)
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
  }, nil
end

---Encodes a Lua table to TOML format (using vendor library)
---@param tbl table The table to encode
---@return string? toml_content The TOML representation
---@return string? error Error message if encoding fails
local function encode(tbl)
  if type(tbl) ~= 'table' then
    return nil, 'Input must be a table'
  end

  local success, result = pcall(toml.encode, tbl)
  if not success then
    return nil, string.format('TOML encoding failed: %s', result)
  end

  logger.debug('Successfully encoded table to TOML', 'TomlParser')
  return result, nil
end

return {
  parse_plugins_toml = parse_plugins_toml,
  parse_file = parse_file,
  encode = encode,
}
