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

local function group_by_depth(t, prefix, depth, result)
  result = result or {} -- array of tables indexed by depth
  prefix = prefix or ''
  depth = depth or 1

  result[depth] = result[depth] or {}

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
      if result[index][key] then
        if type(result[index][key]) ~= 'table' then
          result[index][key] = { result[index][key] }
        end
        table.insert(result[index][key], v)
      else
        result[index][key] = v
      end
    else
      group_by_depth(v, key, depth + 1, result)
    end
  end

  return result
end

-- [1]:{ foo = 1 }
-- [2]:{ ["bar.baz"] = 1, ["bar.loo"] = "loo" }
-- [3]:{ ["bar.qux.zap"] = 42, ["bar.qux.zoop"] = "zoop" }
-- [4]:{ ["bar.qux.zoop.zip"] = 42 } -- FIXME: The key contains a 'number' type
-- [5]:{ ["bar.qux.zoop.zoop.zop"] = 42 }

---Function to split the key. Sub-key it's the last part of a string delimited by '.' using regex.
---The new key is the first part of the string.
---
---@param str string The string to split
---@return string, string The new key and the sub-key
local function split_key(str)
  local sub_key = str:match('([^.]*)$')
  local new_key = str:sub(1, #str - #sub_key - 1)

  return new_key, sub_key
end

---Combine grouped by depth and key into a single table by splitting the key to new key and sub-key
---and then merging the values into a table.
---
---@param t table<number, table<string, any>> The table to group by depth and key
---@return table<number, table<string, any>> result The result table structured by combined key
---@diagnostic disable-next-line: unused-function
local function combine_by_equal_keys(t)
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
---@param a any The value to check
---@return boolean is_array The result of the check and whether it's an array
---@return boolean is_values_tables The result of the check and whether the values are tables
---@diagnostic disable-next-line: unused-function, unused-local
local function is_array(a)
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
  end

  -- if all keys are numbers, then it's an array
  return _is_array, is_values_tables
end

local foo = {
  evil = { 1, { 'b', false, 10 }, { key1 = 'val', key2 = true } },
  list_of_dicts = { { foo = 1, bar = 2 }, { foo = 3, bar = 4 } },
  foo = 1,
  bar = {
    baz = 1,
    loo = 'loo',
    qux = {
      zap = 42,
      zoop = { zip = 42, zoop = { zop = 42 }, 'zoop' },
      dict = { 'blah', 42, true, false },
      list_of_dicts = { { foo = 1, bar = 2 }, { foo = 3, bar = 4 } },
    },
  },
}

local array = { 1, 2, 3 }
local dict = { foo = 1, bar = 2 }
local array_of_dicts = { dict, dict }

-- local _is_array, is_values_tables = is_array(array)
-- print(('Is Array: "%s", Is Values Tables: "%s"'):format(_is_array, is_values_tables))

-- print(vim.inspect(group_by_depth(foo)))

-- for k, v in sorted_pairs(group_by_depth(foo)) do
--   print('[' .. k .. ']' .. ':' .. vim.inspect(v))
-- end
--
-- for k, v in sorted_pairs(group_by_depth(foo)) do
--   if type(v) == 'table' then
--     for kk, vv in sorted_pairs(v) do
--       local new_key, sub_key = split_key(kk)
--       print('[' .. new_key .. ']' .. ':' .. sub_key .. ' = ' .. vim.inspect(vv))
--     end
--   end
-- end

local bar = combine_by_equal_keys(group_by_depth(foo))
for k, v in sorted_pairs(bar) do
  print('[' .. k .. ']' .. ':' .. vim.inspect(v))
end

-- print(vim.inspect(bar))
