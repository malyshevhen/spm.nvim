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
  SINGLE_OPEN_BRACKET = '[',
  DOUBLE_OPEN_BRACKET = '[[',
  SINGLE_CLOSE_BRACKET = ']',
  DOUBLE_CLOSE_BRACKET = ']]',
  SINGLE_OPEN_BRACE = '{',
  SINGLE_CLOSE_BRACE = '}',
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
---  first = true,
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
---  [1] = {
---    ['first'] = true,
---  },
---  [3] = {
---    ['foo.bar.baz'] = 1,
---  },
---  [4] = {
---    ['foo.bar.qux.zap'] = 42,
---  },
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
  ---@param t table<string, any> The table to group
  ---@param prefix string The prefix to prepend to the key
  ---@param depth number The current depth
  ---@param acc table<number, table<string, any>> The accumulator table
  ---@return table<number, table<string, any>> The accumulator table
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

      if v and (type(k) ~= 'string' or type(v) ~= 'table') then
        acc[index] = acc[index] or {}
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
        acc[depth + 1] = acc[depth + 1] or {}
        _group_by_depth_and_keys(v, key, depth + 1, acc)
      end
    end
    return acc
  end

  return _group_by_depth_and_keys(obj, _prefix, _depth, _acc)
end

-- FIXME: incorrect result after indexing
---Combine grouped by depth and key into a single table by defining the common keys
---and then merging the values into a tables.
---
---@param t table<number, table<string, any>> The table to group by depth and key
---@return table<number, table<string, any>> result The result table structured by combined key
---@diagnostic disable-next-line: unused-function
local function normalize_by_keys(t)
  ---@type table<number, table<string, any>>
  local result = {}

  for d, o in ipairs(t) do
    result[d] = result[d] or {}

    for k, v in pairs(o) do
      local new_key, sub_key = split_key(k)
      result[d][new_key] = result[d][new_key] or {}

      if d == 1 then
        result[d][new_key] = v
        goto continue
      end

      if sub_key and result[d][new_key][sub_key] then
        if type(result[d][new_key][sub_key]) ~= 'table' then
          result[d][new_key][sub_key] = { result[d][new_key][sub_key] }
        end
        table.insert(result[d][new_key][sub_key], v)
      else
        result[d][new_key][sub_key] = v
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
---@param a any The value to check
---@return boolean is_array The result of the check and whether it's an array
local function is_array(a)
  if type(a) ~= 'table' then
    return false
  end

  local len = #a -- count the number of keys in the table
  if len == 0 then
    return false -- if the table has no indexed keys, then it's an array (assuming that empty table is a dictionary)
  end

  local _is_array = true

  for k, _ in pairs(a) do
    if type(k) ~= 'number' then
      return false
    end
  end

  -- if all keys are numbers, then it's an array
  return _is_array
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
  -- v = v:gsub('\\', '\\') -- NOTE: Check if this is needed

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

  -- if the value is not a string, convert it to a string
  if type(v) ~= 'string' then
    v = tostring(v)
  else
    v = parse_string(v)
  end

  return k .. SPACE_EQUALS_SPACE .. v
end

---Parse array in flat format
---
---@param v any[] The value of the array
---@return string The updated accumulator
function parse_array_flat(v)
  if #v == 0 then
    return ''
  end

  ---@type string[]
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
  end

  return SYMBOL.SINGLE_OPEN_BRACKET .. table.concat(acc, ', ') .. SYMBOL.SINGLE_CLOSE_BRACKET
end

---@param kt string The key template
---@param k string The key of the dictionary
---@param v table<string, any> The value of the dictionary
---@return string The parsed dictionary table
local function parse_dict_table(kt, k, v)
  local acc = ''

  for kk, vv in sorted_pairs(v) do
    if type(vv) ~= 'table' then
      acc = acc .. kt:gsub('{k}', kk) .. parse_primitive_key_val(kk, vv)
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
  if type(v) ~= 'table' then
    acc = acc .. k .. SPACE_EQUALS_SPACE .. type(v) == 'string' and parse_string(k) or tostring(v)
  elseif is_array(v) then
    acc = acc .. k .. SPACE_EQUALS_SPACE .. parse_array_flat(v)
  elseif is_dict(v) then
    local kt = SYMBOL.SINGLE_OPEN_BRACKET
      .. k
      .. '.{k}'
      .. SYMBOL.SINGLE_CLOSE_BRACKET
      .. SYMBOL.NEWLINE

    acc = acc
      .. SYMBOL.DOUBLE_OPEN_BRACKET
      .. k
      .. SYMBOL.DOUBLE_CLOSE_BRACKET
      .. SYMBOL.NEWLINE
      .. parse_dict_table(kt, k, v)
  else
    error('Mixed table format, input is corrupted')
  end

  return acc
end

---Parse dictionary in flat format
---
---@param v table<string, any> The value of the dictionary
---@return string The updated accumulator
function parse_dict_flat(v)
  local acc = {}
  local i = 1
  for kk, vv in sorted_pairs(v) do
    if type(vv) ~= 'table' then
      acc[i] = parse_primitive_key_val(kk, vv)
    elseif is_array(vv) then
      acc[i] = parse_array_flat(vv)
    elseif is_dict(vv) then
      acc[i] = parse_dict_flat(vv)
    else
      error('Mixed table format, input is corrupted')
    end
    i = i + 1
  end

  return SYMBOL.SINGLE_OPEN_BRACE
    .. SYMBOL.SPACE
    .. table.concat(acc, SYMBOL.COMMA .. SYMBOL.SPACE)
    .. SYMBOL.SPACE
    .. SYMBOL.SINGLE_CLOSE_BRACE
end

---Define the behavior of the table and delegate to the appropriate function
---
---
---@param o table<number, table<string, any>> The table to parse
---@return string The updated accumulator
---@diagnostic disable-next-line: unused-function, unused-local
local function parse_object(o)
  if #o == 0 then
    error('Only tables with normalized structure could be parsed')
  end

  local acc = ''

  for i, l in ipairs(o) do
    for k, v in sorted_pairs(l) do
      if type(v) ~= 'table' then
        acc = acc .. parse_primitive_key_val(k, v) .. SYMBOL.NEWLINE
      elseif is_array(v) then
        acc = acc .. parse_array(k, v) .. SYMBOL.NEWLINE
      elseif is_dict(v) then
        local kt = SYMBOL.SINGLE_OPEN_BRACKET .. k .. SYMBOL.SINGLE_CLOSE_BRACKET .. SYMBOL.NEWLINE
        acc = acc .. parse_dict_table(kt, k, v)
      else
        error('Mixed table format, input is corrupted')
      end
    end
  end

  return acc
end

function encoder.encode(tbl)
  -- check if it's a table and do not an array
  if not is_dict(tbl) then
    error('Only tables with a key-value structure are supported')
  end

  -- group the table by depth and key
  local grouped = group_by_depth_and_keys(tbl)
  local combined = normalize_by_keys(grouped)

  local result = parse_object(combined)
  return result
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
