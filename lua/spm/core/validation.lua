--- A type enum for the valid strings returned by Lua's `type()` function.
---@alias spm.Schema.LuaType
---| '"string"'
---| '"number"'
---| '"boolean"'
---| '"table"'
---| '"function"'
---| '"thread"'
---| '"userdata"'
---| '"nil"'

--- Defines the validation rules for a single field.
---@class spm.Schema.Constraint
---@field type spm.Schema.LuaType | spm.Schema.LuaType[] The expected Lua type of the field (e.g., 'string', 'boolean', 'table').
---@field optional boolean? If true, the field does not need to be present. Defaults to false.
---@field regex string? An optional regex pattern that the field's value must match. (Only applies to strings)
---@field enum any[]? An optional list of allowed values for the field.
---@field custom fun(value: any, data: table): (boolean, string?)? An optional custom validation function.
---                  It receives the field's value and the full data table, and should return `true` on success,
---                  or `false` and an error message on failure.

--- Defines the structure of a full validation schema.
--- It's a map where keys are field names and values are constraint definitions.
---@alias spm.Schema.Definition table<string, spm.Schema.Constraint>

--- A contract for objects that can be validated.
--- They must provide a 'schema' table that defines the validation rules.
---@class spm.Valid
---@field schema spm.Schema.Definition A validation schema.

--- A generic, schema-driven validation module for Lua tables.
--- It validates a target object against a schema provided by the object itself,
--- adhering to the `spm.Valid` interface contract.
local Validator = {}

-- Forward declare the internal recursive function for clarity.
---@type fun(target: spm.Valid, visited: table): boolean, string?
local _validate

--- Validates a data object that implements the `spm.Valid` interface.
--- This function serves as the public entry point, setting up the initial state for recursion.
---@param target spm.Valid The object to validate.
---@return boolean, string? `true` if the object is valid, otherwise `false` and an error message string.
function Validator.validate(target)
  -- The 'visited' table is used to detect cyclical references and prevent infinite recursion.
  -- It is created once at the start of the top-level validation call.
  local visited = {}
  return _validate(target, visited)
end

--- Internal recursive validation function.
---@param target spm.Valid The object to validate.
---@param visited table A set-like table tracking objects already validated in this call stack.
---@return boolean, string?
_validate = function(target, visited)
  if type(target) ~= 'table' then return false, 'Target for validation must be a table.' end

  -- Cycle Detection: If we have already seen this exact table, skip it.
  -- This prevents infinite loops in circular data structures.
  if visited[target] then return true, nil end
  visited[target] = true

  -- Duck Typing: Check if the target is validatable by looking for a schema.
  local schema = target.schema
  if type(schema) ~= 'table' then
    -- This is not an error, it just means this table doesn't need validation.
    return true, nil
  end

  for field_name, constraints in pairs(schema) do
    local value = target[field_name]

    if value == nil then
      if not constraints.optional then
        return false, string.format("Missing required field: '%s'", field_name)
      end
    else
      -- 1. Type Check (Now with multi-type support)
      local constraints_type = constraints.type
      local value_type = type(value)
      local type_is_valid = false

      if type(constraints_type) == 'string' then
        -- Case 1: A single type is specified
        if value_type == constraints_type then type_is_valid = true end
      elseif type(constraints_type) == 'table' then
        -- Case 2: A list of allowed types is specified
        for _, allowed_type in ipairs(constraints_type) do
          if value_type == allowed_type then
            type_is_valid = true
            break -- Found a match, no need to check further
          end
        end
      end

      if not type_is_valid then
        -- Create a user-friendly error message for both cases
        local expected_type_str
        if type(constraints_type) == 'string' then
          expected_type_str = "'" .. constraints_type .. "'"
        else
          expected_type_str = "one of ['" .. table.concat(constraints_type, "', '") .. "']"
        end
        return false,
          string.format(
            "Field '%s' must be of type %s, but received type '%s'",
            field_name,
            expected_type_str,
            value_type
          )
      end
      -- 2. Regex Check (only for string values)
      if constraints.regex and type(value) == 'string' then
        local success, matched = pcall(string.match, value, constraints.regex)
        if not success then
          return false,
            string.format(
              "Field '%s' has an invalid regex pattern in its schema: %s",
              field_name,
              tostring(matched)
            )
        end
        if not matched then
          return false,
            string.format(
              "Field '%s' with value '%s' does not match the required regex pattern: '%s'",
              field_name,
              value,
              constraints.regex
            )
        end
      end
      -- 3. Enum Check (for any value type)
      if constraints.enum then
        local found = false
        for _, allowed_value in ipairs(constraints.enum) do
          if value == allowed_value then
            found = true
            break
          end
        end
        if not found then
          return false,
            string.format(
              "Field '%s' has an invalid value '%s'. It must be one of [%s]",
              field_name,
              tostring(value),
              table.concat(constraints.enum, ', ')
            )
        end
      end
      -- 4. Custom Validation Function
      if constraints.custom then
        local is_ok, err_msg = constraints.custom(value, target)
        if not is_ok then
          return false,
            string.format(
              "Field '%s' failed custom validation: %s",
              field_name,
              err_msg or 'invalid value'
            )
        end
      end
      -- 5. Recursive Validation Logic
      if type(value) == 'table' then
        -- Check if the value is an array-like table.
        if value[1] ~= nil then
          -- It's an array. Recursively validate each item.
          for i, item in ipairs(value) do
            if type(item) == 'table' then
              local ok, err = _validate(item, visited)
              if not ok then
                return false,
                  string.format(
                    "Validation failed for field '%s' at index %d: %s",
                    field_name,
                    i,
                    err
                  )
              end
            end
          end
        else
          -- It's a dictionary-like table. Recursively validate it.
          local ok, err = _validate(value, visited)
          if not ok then
            return false,
              string.format("Validation failed for nested field '%s': %s", field_name, err)
          end
        end
      end
    end
  end

  return true, nil
end

--- A mixin/trait that provides validation capabilities to any class.
--- A class that uses this mixin is expected to implement the `spm.Valid` interface
---@class spm.Validatable: spm.Valid
local Validatable = {}

--- Validates the instance against its own schema.
--- This method is intended to be called on an instance of a class that uses this mixin.
---@return boolean?, string? The instance itself if valid, otherwise nil and an error message.
function Validatable:valid()
  -- We assume 'self' will be an instance of a data class like Config or User.
  return Validator.validate(self)
end

return {
  Validatable = Validatable,
  Validator = Validator,
}
