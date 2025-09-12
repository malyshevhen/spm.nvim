--- Usage examples:
--
-- -- Basic usage
-- ```lua
-- local result1 = Result.ok('Hello World')
-- local result2 = Result.err('Something went wrong')
--
-- print(result1:is_ok())  -- true
-- print(result2:is_err()) -- true
--
-- -- Chaining operations
-- local final_result = Result.ok(5)
--     :map(function(x) return x * 2 end)
--     :map(tostring)
--     :unwrap() -- "10"
--
-- print("Expected: 10, got: " .. final_result)
-- print("Type of final_result: " .. type(final_result))
--
-- -- Error handling
-- local safe_divide = function(a, b)
--   if b == 0 then
--     return Result.err('Division by zero')
--   end
--   return Result.ok(a / b)
-- end
--
-- local result = safe_divide(10, 2)
--     :map(function(x) return x * 3 end)
--     :unwrap_or(0) -- 15
--
-- print("Expected: 15, got: " .. result)
--
-- -- Using with existing functions
-- local file_result = Result.try(function()
--   return vim.fn.readfile('some_file.txt')
-- end)
--
-- if file_result:is_ok() then
--   local lines = file_result:unwrap()
--   -- process lines
-- end
-- ```

---@class Error
---@field message string
---@field code string?
---@field stack string?

---@generic T
---@class Result<T>
---@field success boolean
---@field error Error?
---@field result `T`?
local Result = {}
Result.__index = Result

---Create a new Result instance
---@generic T
---@param success boolean
---@param result T?
---@param error Error?
---@return Result<T>
function Result.new(success, result, error)
  return setmetatable({
    success = success,
    result = result,
    error = error,
  }, Result)
end

---Create a successful result
---@generic T
---@param result T
---@return Result<T>
function Result.ok(result) return Result.new(true, result, nil) end

---Create an error result
---@generic T
---@param error Error|string
---@return Result<T>
function Result.err(error)
  if type(error) == 'string' then error = { message = error } end
  return Result.new(false, nil, error)
end

---Check if result is successful
---@return boolean
function Result:is_ok() return self.success end

---Check if result is an error
---@return boolean
function Result:is_err() return not self.success end

---Get the result value, throwing error if unsuccessful
---@generic T
---@return T
function Result:unwrap()
  if not self.success then
    error(
      'Called unwrap on error result: ' .. (self.error and self.error.message or 'Unknown error')
    )
  end
  return self.result
end

---Get the result value or return a default
---@generic T
---@param default T
---@return T
function Result:unwrap_or(default) return self.success and self.result or default end

---Get the error value
---@return Error
function Result:unwrap_err() return self.error end

---Map the result value if successful
---@generic T, U
---@param fn fun(value: T): U
---@return Result<U>
function Result:map(fn)
  if not self.success then return Result.err(self.error) end

  local ok, mapped_result = pcall(fn, self.result)
  if not ok then
    return Result.err({ message = 'Map function failed: ' .. tostring(mapped_result) })
  end

  return Result.ok(mapped_result)
end

---Map the error message value if unsuccessful
---@generic T
---@param fn fun(error: string): T
---@return Result<T>
function Result:map_err(fn)
  if self.success then return Result.ok(self.result) end
  local ok, mapped_error = pcall(fn, self.error.message)
  if not ok then
    return Result.err({ message = 'Map_err function failed: ' .. tostring(mapped_error) })
  end

  return Result.err(mapped_error)
end

---FlatMap the result value if successful
---@generic T, U
---@param fn fun(value: T): Result<U>
---@return Result<U>
function Result:flat_map(fn)
  if not self.success then return Result.err(self.error) end

  local ok, next_result = pcall(fn, self.result)
  if not ok then
    return Result.err({ message = 'Flat_map function failed: ' .. tostring(next_result) })
  end

  -- Ensure the function returned a Result
  if type(next_result) ~= 'table' or next_result.success == nil then
    return Result.err({ message = 'Flat_map function must return a Result' })
  end

  return next_result
end

---Handle error case
---@generic T
---@param fn fun(): T
---@return Result<T>
function Result:or_else(fn)
  if self.success then return self end

  local ok, recovery_result = pcall(fn)
  if not ok then
    return Result.err({ message = 'Or_else function failed: ' .. tostring(recovery_result) })
  end

  return Result.ok(recovery_result)
end

---Create Result from a function that might throw
---@generic T
---@param fn fun(): T
---@return Result<T>
function Result.try(fn)
  local ok, result = pcall(fn)
  if not ok then return Result.err({ message = tostring(result) }) end

  return Result.ok(result)
end

---Create Result from success/error tuple (common Lua pattern)
---@generic T
---@param success boolean
---@param value_or_error T|string
---@return Result<T>
function Result.from_tuple(success, value_or_error)
  if not success then
    return Result.err(
      type(value_or_error) == 'string' and { message = value_or_error } or value_or_error
    )
  end

  return Result.ok(value_or_error)
end

---Convert to string representation
---@return string
function Result:__tostring()
  if not self.success then
    return ('Err(%s)'):format(vim.inspect(self.error and self.error.message or 'Unknown error'))
  end

  return string.format('Ok(%s)', vim.inspect(self.result))
end

return {
  Result = Result,
}
