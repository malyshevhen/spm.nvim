---A TOML v1.0.0 parser for Lua.
---
---Converts a TOML-formatted string into a Lua table.
---
---Features:
---  Key/value pairs
---  All major data types: Strings (basic, literal, multiline), Integers, Floats, Booleans
---  Datetimes are parsed as strings
---  Arrays (including multiline)
---  Inline Tables
---  Standard Tables `[table]`
---  Dotted Keys `a.b.c`
---  Arrays of Tables `[[products]]`
---  Comments
---
--- Limitations:
---  Does not parse TOML Datetimes into a special date object; they remain strings.
---  Does not support complex unicode escape sequences (`\uXXXX`, `\UXXXXXXXX`) in strings.
---
--- Usage:
---    local toml = require("toml")
---    local toml_string = [=[
---        # This is a TOML document.
---        title = "TOML Example"
---
---        [owner]
---        name = "Tom Preston-Werner"
---        dob = 1979-05-27T07:32:00-08:00 # First-class date
---
---        [database]
---        server = "192.168.1.1"
---        ports = [ 8001, 8001, 8002 ]
---        data = [ ["delta", "phi"], [3.14] ]
---        enabled = true
---
---        # Array of Tables
---        [[products]]
---        name = "Hammer"
---        sku = 738594937
---
---        [[products]]
---        name = "Nail"
---        sku = 284758393
---        color = "gray"
---    ]=]
---
---    local success, data_or_error = pcall(toml.parse, toml_string)
---
---    if success then
---        -- Use the parsed data
---        print(data_or_error.owner.name) -- Tom Preston-Werner
---        print(data_or_error.products[2].name) -- Nail
---    else
---        -- Handle the error
---        print("Error parsing TOML:", data_or_error)
---    end

---@module 'toml.parser'
local parser = {}

-- =============================================
-- Helper Functions
-- =============================================
local function trim(s) return s:match('^%s*(.-)%s*$') end

local function p_error(message, line_num)
  error(string.format('TOML Parse Error (line %d): %s', line_num, message), 2)
end

local function resolve_key_path(root_table, key_path, line_num)
  local current_table = root_table
  local parts = {}
  for part in key_path:gmatch('([^."\']+)') do
    table.insert(parts, part)
  end

  for i = 1, #parts - 1 do
    local part = parts[i]
    if not current_table[part] then
      current_table[part] = {}
    elseif type(current_table[part]) ~= 'table' then
      p_error("Cannot redefine key '" .. part .. "' as a table.", line_num)
    end
    current_table = current_table[part]
  end

  return current_table, parts[#parts]
end

-- =============================================
-- Value Parsers
-- =============================================
local parse_value -- forward declare

local function parse_string(val_str, line_num)
  local is_multi_basic = val_str:sub(1, 3) == '"""'
  local is_multi_literal = val_str:sub(1, 3) == "'''"
  if is_multi_basic or is_multi_literal then return val_str:sub(4, -4) end

  local quote_char = val_str:sub(1, 1)
  if quote_char ~= '"' and quote_char ~= "'" then p_error('Invalid string value.', line_num) end
  local content = val_str:sub(2, -2)
  if quote_char == '"' then
    local escapes = {
      ['"'] = '"',
      ['\\'] = '\\',
      ['/'] = '/',
      ['b'] = '\b',
      ['f'] = '\f',
      ['n'] = '\n',
      ['r'] = '\r',
      ['t'] = '\t',
    }
    content = content:gsub('\\(.)', function(c) return escapes[c] or c end)
  end
  return content
end

local function parse_array(val_str, line_num)
  local content = trim(val_str:sub(2, -2))
  if content == '' then return {} end

  local array = {}
  local nesting = 0
  local last_split = 1

  for i = 1, #content do
    local char = content:sub(i, i)
    if char == '[' or char == '{' then
      nesting = nesting + 1
    elseif char == ']' or char == '}' then
      nesting = nesting - 1
    elseif char == ',' and nesting == 0 then
      local element_str = content:sub(last_split, i - 1)
      table.insert(array, parse_value(element_str, line_num))
      last_split = i + 1
    end
  end

  -- Add the last element, but only if it's not empty (handles trailing commas)
  local last_element_str = trim(content:sub(last_split))
  if last_element_str ~= '' then table.insert(array, parse_value(last_element_str, line_num)) end

  return array
end

local function parse_inline_table(val_str, line_num)
  local content = trim(val_str:sub(2, -2))
  if content == '' then return {} end
  local tbl = {}
  local nesting = 0
  local last_split = 1
  local pairs = {}
  for i = 1, #content do
    local char = content:sub(i, i)
    if char == '[' or char == '{' then
      nesting = nesting + 1
    elseif char == ']' or char == '}' then
      nesting = nesting - 1
    elseif char == ',' and nesting == 0 then
      table.insert(pairs, content:sub(last_split, i - 1))
      last_split = i + 1
    end
  end
  table.insert(pairs, content:sub(last_split))
  for _, pair_str in ipairs(pairs) do
    local key, val = pair_str:match('([^=]+)=(.*)')
    if not key or not val then p_error('Invalid key-value pair in inline table.', line_num) end
    key = trim(key)
    tbl[key] = parse_value(val, line_num)
  end
  return tbl
end

parse_value = function(val_str, line_num)
  val_str = trim(val_str)
  if val_str == 'true' then return true end
  if val_str == 'false' then return false end
  local first_char = val_str:sub(1, 1)
  if first_char == '"' or first_char == "'" then return parse_string(val_str, line_num) end
  if first_char == '[' then return parse_array(val_str, line_num) end
  if first_char == '{' then return parse_inline_table(val_str, line_num) end
  if val_str:match('^%d%d%d%d%-%d%d%-%d%d') then return val_str end
  if val_str:match('^[+-]?%d') and not val_str:match('[^%d%.eE_%+-]') then
    local num = tonumber((val_str:gsub('_', '')))
    if num ~= nil then return num end
    p_error('Invalid number format: ' .. val_str, line_num)
  end
  if val_str == 'inf' or val_str == '+inf' then return 1 / 0 end
  if val_str == '-inf' then return -1 / 0 end
  if val_str == 'nan' or val_str == '+nan' or val_str == '-nan' then return 0 / 0 end
  p_error('Could not parse value: ' .. val_str, line_num)
end

-- =============================================
-- Line Parsers
-- =============================================

local function handle_key_value(line, current_table, line_num)
  local key_str, value_str = line:match('([^=]+)=(.*)')
  if not key_str or not value_str then p_error('Invalid key-value pair.', line_num) end
  key_str = trim(key_str)
  local target_table, final_key = resolve_key_path(current_table, key_str, line_num)
  if target_table[final_key] then
    p_error("Redefinition of key '" .. final_key .. "' is not allowed.", line_num)
  end
  target_table[final_key] = parse_value(value_str, line_num)
end

local function handle_table(line, root, line_num, defined_tables)
  local path_str = line:match('^%[(.+)%]$')
  path_str = trim(path_str)
  if defined_tables[path_str] then
    p_error('Redefinition of table `[' .. path_str .. ']` is not allowed.', line_num)
  end
  defined_tables[path_str] = true
  local parts = {}
  for part in path_str:gmatch('([^."\']+)') do
    table.insert(parts, part)
  end
  local current = root
  for _, part in ipairs(parts) do
    if not current[part] then
      current[part] = {}
    elseif type(current[part]) ~= 'table' then
      p_error("Key '" .. part .. "' was already defined as a non-table value.", line_num)
    end
    current = current[part]
  end
  return current
end

local function handle_array_of_tables(line, root, line_num)
  local path_str = line:match('^%[%[(.+)%]%]$')
  path_str = trim(path_str)
  local parent_table, array_key = resolve_key_path(root, path_str, line_num)
  if not parent_table[array_key] then
    parent_table[array_key] = {}
  elseif type(parent_table[array_key]) ~= 'table' or not parent_table[array_key][1] then
    p_error("Key '" .. array_key .. "' was not defined as an array of tables.", line_num)
  end
  local new_table = {}
  table.insert(parent_table[array_key], new_table)
  return new_table
end

-- =============================================
-- Main Parser
-- =============================================

-- TODO: refactor this (split into smaller functions)
--- Parses a TOML-formatted string into a Lua table.
---@param toml_string string TOML-formatted string to parse
---@return table parsed_toml Parsed TOML content
function parser.parse(toml_string)
  local root, current_table, defined_tables = {}, {}, {}
  current_table = root
  local line_num = 0
  local in_multiline_string, multiline_key, multiline_lines, multiline_terminator, multiline_target_table
  local in_multiline_array, multiline_array_buffer, multiline_array_line, multiline_array_start_line =
    false, '', '', 0

  for line in toml_string:gmatch('([^\r\n]*)') do
    line_num = line_num + 1
    if in_multiline_string then
      if line:find(multiline_terminator, 1, true) then
        local content_part = line:match('(.+)' .. multiline_terminator)
        if content_part then table.insert(multiline_lines, content_part) end
        local final_content = table.concat(multiline_lines, '\n')
        if final_content:sub(1, 1) == '\n' then final_content = final_content:sub(2) end
        multiline_target_table[multiline_key] = final_content
        in_multiline_string = false
      else
        table.insert(multiline_lines, line)
      end
    elseif in_multiline_array then
      multiline_array_buffer = multiline_array_buffer .. ' ' .. trim(line:match('^([^#]*)'))
      local nesting = 0
      for i = 1, #multiline_array_buffer do
        local char = multiline_array_buffer:sub(i, i)
        if char == '[' or char == '{' then
          nesting = nesting + 1
        elseif char == ']' or char == '}' then
          nesting = nesting - 1
        end
      end
      if nesting == 0 then
        handle_key_value(
          multiline_array_line .. multiline_array_buffer,
          current_table,
          multiline_array_start_line
        )
        in_multiline_array = false
      end
    else
      local clean_line = trim(line:match('^([^#]*)'))
      if clean_line ~= '' then
        if clean_line:match('^%[%[.+%]%]$') then
          current_table = handle_array_of_tables(clean_line, root, line_num)
        elseif clean_line:match('^%[.+%]$') then
          current_table = handle_table(clean_line, root, line_num, defined_tables)
        elseif clean_line:find('=') then
          local key_str, value_str = clean_line:match('([^=]+)=(.*)')
          value_str = trim(value_str)
          local is_multi_start = value_str:sub(1, 3) == '"""' or value_str:sub(1, 3) == "'''"
          if is_multi_start and not value_str:find(value_str:sub(1, 3), 4) then
            in_multiline_string = true
            multiline_terminator = value_str:sub(1, 3)
            local target, key = resolve_key_path(current_table, trim(key_str), line_num)
            multiline_key, multiline_target_table, multiline_lines = key, target, {}
          else
            local nesting = 0
            for i = 1, #value_str do
              local char = value_str:sub(i, i)
              if char == '[' or char == '{' then
                nesting = nesting + 1
              elseif char == ']' or char == '}' then
                nesting = nesting - 1
              end
            end
            if nesting > 0 then
              in_multiline_array = true
              multiline_array_start_line = line_num
              multiline_array_line = key_str .. '='
              multiline_array_buffer = value_str
            else
              handle_key_value(clean_line, current_table, line_num)
            end
          end
        else
          p_error('Invalid syntax.', line_num)
        end
      end
    end
  end
  if in_multiline_string then p_error('Unterminated multiline string.', line_num) end
  if in_multiline_array then
    p_error('Unterminated multiline array.', multiline_array_start_line)
  end
  return root
end

return parser
