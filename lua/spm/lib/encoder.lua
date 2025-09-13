--- Encodes a table into TOML recursively.
---@class spm.TomlEncoder
local encoder = {}

local function read_only(t)
  return setmetatable({}, {
    __index = t,
    __newindex = function(_, k, v) error('Attempt to modify read-only table', 2) end,
    __metatable = false, -- prevent changing the metatable
  })
end

---@enum toml.Symbol
local SYMBOL = read_only({
  SINGLE_QUOTE = "'",
  DOUBLE_QUOTE = '"',
  MULTI_LINE_QUOTE = '"""',
  SINGE_OPEN_BRACKET = '[',
  DOUBLE_OPEN_BRACKET = '[[',
  SINGE_CLOSE_BRACKET = ']',
  DOUBLE_CLOSE_BRACKET = ']]',
  SINGE_OPEN_BRACE = '{',
  SINGE_CLOSE_BRACE = '}',
  SPACE = ' ',
  EQUALS = '=',
  PERIOD = '.',
  COMMA = ',',
  NEWLINE = '\n',
  BACKSPACE = '\b',
  TAB = '\t',
  FORMFEED = '\f',
  CARRIAGE = '\r',
  NULL = '\0',
})

local SPACE_EQUALS_SPACE = SYMBOL.SPACE .. SYMBOL.EQUALS .. SYMBOL.SPACE

---Function to split the key.
---The new key is the first part of the string, and the sub-key is the last part of the string.
---If the string does not contain a dot, the sub-key is an empty string.
---The new key is the first part of the string.
---
---Example:
---```
---local new_key, sub_key = split_key('foo.bar.baz')
---
---assert(new_key == 'foo.bar')
---assert(sub_key == 'baz')
---
---
---local new_key, sub_key = split_key('foo')
---
---assert(new_key == 'foo')
---assert(sub_key == '')
---```
---
---@param str string The string to split
---@return string, string The new key and the sub-key
local function split_key(str)
  local new_key, sub_key = str:match('^(.*)%.([^.]*)$')

  if new_key and sub_key then
    return new_key, sub_key
  end
  -- No dot found, return whole string as new_key
  return str, ''
end

---Sorted iterator
---@param t table The table to iterate over
---@return function iterator
---@diagnostic disable-next-line: unused-function, unused-local
local function sorted_pairs(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys)

  local i = 0
  return function()
    i = i + 1
    local key = keys[i]
    if key then
      return key, t[key]
    end
  end
end

---Group a table by depth and key by recursively traversing the table, concatenating the keys by the
---period character, and then grouping the values by the key.
---
---This function is use recursive call under the hood.
---
---```
--- -- input
---{
---  foo = {
---    bar = {
---      baz = 1,
---      qux = {
---        zap = 42,
---      },
---    },
---  },
---}
---
--- -- output
---{
---  foo.bar.baz = 1,
---  foo.bar.qux.zap = 42,
---}
---```
---
---@param obj table<string, any> Free-form dictionary
---@return table<number, table<string, any>> result The result table indexed by depth and key
---@diagnostic disable-next-line: unused-function
local function group_by_depth_and_keys(obj)
  local _acc = {} -- array of tables indexed by depth
  local _prefix = ''
  local _depth = 1

  _acc[1] = {}

  -- recursive helper function
  local function _group_by_depth_and_keys(t, prefix, depth, acc)
    for k, v in pairs(t) do
      local key = prefix
      local index = depth

      if type(k) == 'number' then
        key = key
        index = index - 1
      else
        key = key ~= '' and (key .. '.' .. k) or k
      end

      if type(k) ~= 'string' or type(v) ~= 'table' then
        -- check if the key already taken. If so, merge the values into a table
        if acc[index][key] then
          if type(acc[index][key]) ~= 'table' then
            acc[index][key] = { acc[index][key] }
          end
          table.insert(acc[index][key], v)
        else
          acc[index][key] = v
        end
      else
        _group_by_depth_and_keys(v, key, depth + 1, acc)
      end
    end
    return acc
  end

  return _group_by_depth_and_keys(obj, _prefix, _depth, _acc)
end

---Combine grouped by depth and key into a single table by defining the common keys
---and then merging the values into a tables.
---
---@param t table<number, table<string, any>> The table to group by depth and key
---@return table<string, any> result The result table structured by combined key
---@diagnostic disable-next-line: unused-function
local function normalize_by_keys(t)
  local result = {}

  for d, o in ipairs(t) do
    for k, v in pairs(o) do
      local new_key, sub_key = split_key(k)

      result[new_key] = result[new_key] or {}

      if d == 1 then
        result[new_key] = v
        goto continue
      end

      if result[new_key][sub_key] then
        if type(result[new_key][sub_key]) ~= 'table' then
          result[new_key][sub_key] = { result[new_key][sub_key] }
        end
        table.insert(result[new_key][sub_key], v)
      else
        result[new_key][sub_key] = v
      end
      ::continue::
    end
  end
  return result
end

---Is array
---should detect if the table is an array of any kind
---could be a table of tables or a table of primitives
---
---Rule:
---- Each key should be a number
---
---Throws an error if the input is mixed
---
---@param a any The value to check
---@return boolean is_array The result of the check and whether it's an array
---@return boolean is_values_tables The result of the check and whether the values are tables
---@diagnostic disable-next-line: unused-function, unused-local
local function is_array(a)
  if type(a) ~= 'table' then
    return false, false
  end

  local len = #a -- count the number of keys in the table
  if len == 0 then
    return false, false -- if the table has no indexed keys, then it's an array (assuming that empty table is a dictionary)
  end

  local _is_array = true
  local is_values_tables = true

  for k, vv in pairs(a) do
    if type(k) ~= 'number' then
      _is_array = false
      return _is_array, is_values_tables
    else
      if type(vv) ~= 'table' then
        is_values_tables = false
      end
    end
    len = len - 1
  end

  -- if table is mixed, input is corrupted
  if len ~= 0 then
    error('Mixed table format, input is corrupted')
  end

  -- if all keys are numbers, then it's an array
  return _is_array, is_values_tables
end

---Is dict
---should detect if the table is a dictionary
---could be a table of tables or a table of primitives
---
---This function is only tells us that the table is a dictionary or not
---it does not tell if the table is a mixed table
---To check if the table is a mixed table, use is_array in addition to this function
---
---Rule:
---- Each key should be a string
---
---@param a any The value to check
---@return boolean is_dict The result of the check and whether it's a dictionary
---@diagnostic disable-next-line: unused-function, unused-local
local function is_dict(a)
  if type(a) ~= 'table' then
    return false
  end

  local len = #a -- count the number of keys in the table
  if len ~= 0 then
    return false -- if the table has indexed keys, then it's not a dictionary, but could be mixed
  end

  for k in pairs(a) do
    if type(k) ~= 'string' then
      return false
    end
  end

  -- if all keys are strings, then it's a dictionary
  return true
end

---@type fun(v: any[]): string
local parse_array_flat

---@type fun(v: table<string, any>): string
local parse_dict_flat

---@param v string The value of the string
---@return string The updated accumulator
---@diagnostic disable-next-line: unused-function, unused-local
local function parse_string(v)
  local quote = SYMBOL.SINGLE_QUOTE
  v = v:gsub('\\', '\\\\')

  -- if the string has any line breaks, make it multiline
  if v:match('^\n(.*)$') then
    quote = SYMBOL.MULTI_LINE_QUOTE
    v = '\\n' .. v
  elseif v:match(SYMBOL.NEWLINE) then
    quote = SYMBOL.MULTI_LINE_QUOTE
  end

  v = v:gsub(SYMBOL.BACKSPACE, '\\b')
  v = v:gsub(SYMBOL.TAB, '\\t')
  v = v:gsub(SYMBOL.FORMFEED, '\\f')
  v = v:gsub(SYMBOL.CARRIAGE, '\\r')
  v = v:gsub('"', '"')

  return quote .. v .. quote
end

---Parse primitive key-value pair
---@param k string The key of the primitive
---@param v string|number|boolean The value of the primitive
---@return string The updated accumulator
local function parse_primitive_key_val(k, v)
  if type(v) == 'table' then
    error('Invalid format, input is corrupted')
  end
  return k .. SPACE_EQUALS_SPACE .. type(v) == 'string' and parse_string(v) or tostring(v)
end

---Parse array in flat format
---
---@param v any[] The value of the array
---@return string The updated accumulator
function parse_array_flat(v)
  if #v == 0 then
    return ''
  end

  local acc = {}
  for i, val in ipairs(v) do
    if type(val) ~= 'table' then
      acc[i] = type(val) == 'string' and parse_string(val) or tostring(val)
    elseif is_array(val) then
      acc[i] = parse_array_flat(val)
    elseif is_dict(v) then
      acc[i] = parse_dict_flat(val)
    else
      error('Mixed table format, input is corrupted')
    end
    acc = acc .. SYMBOL.COMMA .. SYMBOL.SPACE
  end

  return table.concat(acc, ', ') .. SYMBOL.NEWLINE
end

local function parse_dict_table(k, v)
  local acc = ''

  local build_header = function(kk)
    return SYMBOL.SINGLE_OPEN_BRACKET
      .. k
      .. '.'
      .. kk
      .. SYMBOL.SINGLE_CLOSE_BRACKET
      .. SYMBOL.NEWLINE
  end

  for kk, vv in sorted_pairs(v) do
    if type(vv) ~= 'table' then
      acc = acc .. build_header(kk) .. parse_primitive_key_val(kk, vv)
    elseif is_array(vv) then
      acc = acc .. kk .. SPACE_EQUALS_SPACE .. parse_array_flat(vv)
    elseif is_dict(vv) then
      acc = acc .. kk .. SPACE_EQUALS_SPACE .. parse_dict_flat(vv)
    else
      error('Mixed table format, input is corrupted')
    end
    acc = acc .. SYMBOL.NEWLINE
  end
  return acc
end

---Define the behavior of the array and delegate to the appropriate function
---
---```
---  # dictionary
---
---  [[key1]]
---  key2 = value
---  key3 = value
---
---  [[key1.key2]]
---  key4 = value
---
---  # array
---  key1 = [value, value]
---```
---
---@param k string The key of the array
---@param v any[] The value of the array
---@return string The updated accumulator
local function parse_array(k, v)
  if #v == 0 then
    return '' -- empty array
  end

  local acc = ''
  for _, val in ipairs(v) do
    if type(val) ~= 'table' then
      acc = acc .. k .. SPACE_EQUALS_SPACE .. type(val) == 'string' and parse_string(k)
        or tostring(val)
    elseif is_array(val) then
      acc = acc .. k .. SPACE_EQUALS_SPACE .. parse_array_flat(val)
    elseif is_dict(v) then
      acc = acc
        .. SYMBOL.DOUBLE_OPEN_BRACKET
        .. k
        .. SYMBOL.DOUBLE_CLOSE_BRACKET
        .. SYMBOL.NEWLINE
        .. parse_dict_table(k, val)
    else
      error('Mixed table format, input is corrupted')
    end
    acc = acc .. SYMBOL.NEWLINE .. SYMBOL.NEWLINE
  end

  return acc
end

---Parse dictionary in flat format
---
---@param v table<string, any> The value of the dictionary
---@return string The updated accumulator
function parse_dict_flat(v)
  local acc = {}
  for kk, vv in sorted_pairs(v) do
    if type(vv) ~= 'table' then
      acc[kk] = parse_primitive_key_val(kk, vv)
    elseif is_array(vv) then
      acc[kk] = parse_array_flat(vv)
    elseif is_dict(vv) then
      acc[kk] = parse_dict_flat(vv)
    else
      error('Mixed table format, input is corrupted')
    end
  end

  return SYMBOL.SINGE_OPEN_BRACE
    .. SYMBOL.SPACE
    .. table.concat(acc, SYMBOL.COMMA)
    .. SYMBOL.SPACE
    .. SYMBOL.SINGE_CLOSE_BRACE
    .. SYMBOL.NEWLINE
end

---Define the behavior of the table and delegate to the appropriate function
---
---
---@param o table<string, any> The table to parse
---@return string The updated accumulator
---@diagnostic disable-next-line: unused-function, unused-local
local function parse_object(o)
  if #o > 0 then
    error('Only tables with a key-value structure could be parsed')
  end

  local acc = ''

  for k, v in sorted_pairs(o) do
    if type(v) ~= 'table' then
      acc = acc .. parse_primitive_key_val(k, v) .. SYMBOL.NEWLINE
    elseif is_array(v) then
      return acc .. parse_array(k, v)
    elseif is_dict(v) then
      return acc .. parse_dict_table(k, v)
    else
      error('Mixed table format, input is corrupted')
    end
  end

  return acc
end

function encoder.encode(tbl)
  -- check if it's a table and do not an array
  if type(tbl) ~= 'table' or type(tbl[1]) ~= 'table' then
    error('Only tables with a key-value structure are supported')
  end

  -- group the table by depth and key
  local grouped = group_by_depth_and_keys(tbl)
  local combined = normalize_by_keys(grouped)

  return parse_object(combined)
end

-- Export local functions for testing
encoder._SYMBOL = SYMBOL
encoder._split_key = split_key
encoder._group_by_depth_and_keys = group_by_depth_and_keys
encoder._normalize_by_keys = normalize_by_keys
encoder._is_array = is_array
encoder._is_dict = is_dict
encoder._read_only = read_only
encoder._parse_object = parse_object
encoder._parse_array = parse_array
encoder._parse_dict_table = parse_dict_table
encoder._parse_dict_flat = parse_dict_flat
encoder._parse_array_flat = parse_array_flat
encoder._parse_string = parse_string

return encoder
