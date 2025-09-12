local logger = require('spm.lib.logger')
local toml = require('spm.vendor.toml')
local Result = require('spm.lib.error').Result

---Safely parses TOML content using the vendor toml.lua library
---@param content string The TOML content to parse
---@return Result<table>
local function safe_parse(content)
  local success, result = pcall(toml.parse, content)
  if not success or type(result) ~= 'table' or next(result) == nil then
    return Result.err(string.format('TOML parsing failed: %s', result))
  end

  return Result.ok(result)
end

---Reads and parses a TOML file
---@param filepath string Path to the TOML file
---@return Result<table>
local function parse_file(filepath)
  logger.debug(string.format('Parsing file: %s', filepath), 'TomlParser')
  if type(filepath) ~= 'string' or vim.fn.filereadable(filepath) == 0 then
    return Result.err(string.format('Cannot read file: %s', filepath))
  end

  logger.debug(string.format('Reading file: %s', filepath), 'TomlParser')
  local file = io.open(filepath, 'r')
  if not file then
    return Result.err(string.format('Cannot open file: %s', filepath))
  end

  logger.debug(string.format('Reading content from file: %s', filepath), 'TomlParser')
  local content = file:read('*all')
  file:close()

  if not content then
    return Result.err(string.format('Failed to read content from file: %s', filepath))
  end

  logger.debug(string.format('Read %d bytes from %s', #content, filepath), 'TomlParser')

  return safe_parse(content):map_err(
    function(err) return string.format('Cannot parse file: %s; %s', filepath, err) end
  )
end

---Parses plugins.toml specifically and returns a PluginConfig
---@param filepath string Path to the plugins.toml file
---@return Result<PluginConfig>
local function parse_plugins_toml(filepath)
  logger.debug(string.format('Parsing plugins.toml: %s', filepath), 'TomlParser')

  local data_result = parse_file(filepath)
  if data_result:is_err() then
    return data_result
  end
  local data = data_result:unwrap()

  if not data.plugins or type(data.plugins) ~= 'table' then
    return Result.err(
      string.format('plugins.toml must contain a [[plugins]] section. File: %s', filepath)
    )
  end

  if #data.plugins == 0 then
    logger.warn('No plugins defined in plugins.toml', 'TomlParser')
  end

  logger.info(
    string.format('Parsed %d plugin definitions from %s', #data.plugins, filepath),
    'TomlParser'
  )

  return Result.ok({
    plugins = data.plugins,
    language_servers = data.language_servers,
    filetypes = data.filetypes,
  })
end

---Encodes a Lua table to TOML format (using vendor library)
---@param value table The table to encode
---@return Result<string>
local function encode(value)
  if type(value) ~= 'table' then
    return Result.err('Input must be a table')
  end

  local success, result = pcall(toml.encode, value)
  if not success then
    return Result.err(string.format('TOML encoding failed: %s', result))
  end

  logger.debug('Successfully encoded table to TOML', 'TomlParser')
  return Result.ok(result)
end

return {
  parse_plugins_toml = parse_plugins_toml,
  parse_file = parse_file,
  encode = encode,
}
