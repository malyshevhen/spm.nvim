--- A Lua module to encode tables into TOML-formatted strings.
---@module 'toml.encoder'
local encoder = {}

--=============================================================================
-- Helper Functions
--=============================================================================

--- Checks if a table is a dense, 1-based integer-keyed sequence (an array).
---@param t table The table to check.
---@return boolean True if the table is an array, false otherwise.
local function is_array(t)
  if type(t) ~= 'table' then return false end
  local max_index, count = 0, 0
  for k, _ in pairs(t) do
    if type(k) ~= 'number' or k < 1 or k % 1 ~= 0 then return false end
    if k > max_index then max_index = k end
    count = count + 1
  end
  return max_index == count
end

-- Forward declaration for recursive serialization
---@type fun(value: any): string
local serialize_value

--- Serializes a Lua string into a TOML-safe string with proper escaping.
---@param s string The string to serialize.
---@return string The TOML-formatted string.
local function serialize_string(s)
  local replacements = {
    ['\\'] = '\\\\',
    ['"'] = '\\"',
    ['\b'] = '\\b',
    ['\t'] = '\\t',
    ['\n'] = '\\n',
    ['\f'] = '\\f',
    ['\r'] = '\\r',
  }
  s = s:gsub('["\b\t\n\f\r]', replacements)
  return '"' .. s .. '"'
end

--- Serializes a Lua array into a TOML inline array.
---@param arr any[] The array table to serialize.
---@return string The TOML-formatted inline array.
local function serialize_array(arr)
  local parts = {}
  for i = 1, #arr do
    table.insert(parts, serialize_value(arr[i]))
  end
  return '[ ' .. table.concat(parts, ', ') .. ' ]'
end

--- Dispatches a Lua value to the appropriate serializer function.
---@param value any The Lua value to serialize.
---@return string The TOML-formatted value.
function serialize_value(value)
  local value_type = type(value)
  if value_type == 'string' then
    return serialize_string(value)
  elseif value_type == 'number' then
    return tostring(value)
  elseif value_type == 'boolean' then
    return tostring(value)
  elseif value_type == 'table' then
    if is_array(value) then
      return serialize_array(value)
    else
      -- Dictionaries cannot be serialized inline, they must be tables/sections.
      -- This indicates a structural error if we try to serialize one inline.
      error('Cannot serialize a dictionary as an inline value.')
    end
  else
    -- TOML doesn't support functions, userdata, etc.
    error('Unsupported data type for TOML serialization: ' .. value_type)
  end
end

--=============================================================================
-- Core Traversal and Encoding Logic
--=============================================================================

-- TODO: refactor this (split into smaller functions)
--- Recursively processes a table to generate TOML sections and key-value pairs.
---@param tbl table The table to process.
---@param path_parts string[] A list of keys representing the path to the current table.
---@return string[] A list of strings representing lines of the TOML output.
local function process_table(tbl, path_parts)
  local output_lines = {}
  local simple_key_values = {}
  local nested_tables = {}
  local array_of_tables = {}

  -- Step 1: Classify all keys in the current table.
  for k, v in pairs(tbl) do
    if type(v) == 'table' then
      if is_array(v) and #v > 0 and type(v[1]) == 'table' and not is_array(v[1]) then
        -- This is the special "Array of Tables" case
        table.insert(array_of_tables, { key = k, value = v })
      elseif is_array(v) then
        -- This is a simple inline array
        table.insert(simple_key_values, { key = k, value = v })
      else
        -- This is a nested table (dictionary)
        table.insert(nested_tables, { key = k, value = v })
      end
    elseif v ~= nil then
      -- This is a simple key-value pair
      table.insert(simple_key_values, { key = k, value = v })
    end
  end

  -- Step 2: Generate the TOML for the current table level.
  local has_content_at_this_level = #simple_key_values > 0
  if has_content_at_this_level then
    -- Only print a header if it's a sub-table, not the root.
    if #path_parts > 0 then
      table.insert(output_lines, '[' .. table.concat(path_parts, '.') .. ']')
    end
    for _, pair in ipairs(simple_key_values) do
      table.insert(output_lines, pair.key .. ' = ' .. serialize_value(pair.value))
    end
  end

  -- Step 3: Recursively process nested tables.
  for _, item in ipairs(nested_tables) do
    local new_path = {}
    for i = 1, #path_parts do
      new_path[i] = path_parts[i]
    end
    table.insert(new_path, item.key)

    -- Add a space for readability if content was already printed.
    if #output_lines > 0 and output_lines[#output_lines] ~= '' then
      table.insert(output_lines, '')
    end
    local sub_lines = process_table(item.value, new_path)
    for _, line in ipairs(sub_lines) do
      table.insert(output_lines, line)
    end
  end

  -- Step 4: Process arrays of tables.
  for _, item in ipairs(array_of_tables) do
    local new_path = {}
    for i = 1, #path_parts do
      new_path[i] = path_parts[i]
    end
    table.insert(new_path, item.key)
    local path_str = table.concat(new_path, '.')

    for _, sub_table in ipairs(item.value) do
      if #output_lines > 0 and output_lines[#output_lines] ~= '' then
        table.insert(output_lines, '')
      end
      table.insert(output_lines, '[[' .. path_str .. ']]')
      -- Unlike normal nested tables, arrays of tables are "flat".
      -- We process their contents directly, not with a recursive call.
      local sub_lines = process_table(sub_table, {})
      for _, line in ipairs(sub_lines) do
        table.insert(output_lines, line)
      end
    end
  end

  return output_lines
end

--- Encodes a Lua table into a TOML-formatted string.
---@param data any The Lua table to encode.
---@return string?, string? An encoded TOML string, or nil and an error message.
function encoder.encode(data)
  if type(data) ~= 'table' then return nil, 'Input must be a table.' end
  local ok, lines = pcall(process_table, data, {})
  if not ok then
    return nil, lines -- 'lines' will contain the error message from pcall.
  end
  return table.concat(lines, '\n')
end

return encoder
