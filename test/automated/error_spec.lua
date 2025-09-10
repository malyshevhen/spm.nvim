---@diagnostic disable: undefined-field

local err = require('spm.error')
local Result = err.Result

describe('error', function()
  it('should create a successful result', function()
    local result = Result.ok('Hello World')
    assert.is_true(result:is_ok())
    assert.are.same('Hello World', result:unwrap())
  end)

  it('should create an error result', function()
    local result = Result.err('Something went wrong')
    assert.is_true(result:is_err())

    local actual = result:unwrap_err()
    assert.are.same('Something went wrong', actual.message)
  end)

  it('should create a result from a tuple', function()
    local result = Result.from_tuple(true, 'Hello World')
    assert.is_true(result:is_ok())
    assert.are.same('Hello World', result:unwrap())
  end)

  it('should create a result from a tuple with an error', function()
    local result = Result.from_tuple(false, 'Something went wrong')
    assert.is_true(result:is_err())

    local actual = result:unwrap_err()
    assert.are.same('Something went wrong', actual.message)
  end)

  it('should create a result from a function that might throw', function()
    local expected = 'Hello World'
    local result = Result.try(function()
      return expected
    end)
    assert.is_true(result:is_ok())

    local actual = result:unwrap()
    assert.are.same(expected, actual)
  end)

  it('should create a result from a function that might throw with an error', function()
    local result = Result.try(function()
      error('Something went wrong')
    end)
    assert.is_true(result:is_err())

    local actual = result:unwrap_err()
    assert.truthy(actual.message:find('Something went wrong'))
  end)

  it('should map a successful result', function()
    local result = Result.ok('Hello World'):map(function(x)
      return x .. ' Universe'
    end)
    assert.is_true(result:is_ok())
    assert.are.same('Hello World Universe', result:unwrap())
  end)

  it('should map an unsuccessful result', function()
    local result = Result.err('Something went wrong'):map(function(x)
      return x .. ' Universe'
    end)
    assert.is.True(result:is_err())

    local actual = result:unwrap_err()
    assert.are.same('Something went wrong', actual.message)
  end)

  it('should map an error result', function()
    local result = Result.err('Something went wrong'):map_err(function(x)
      return x .. ' Universe'
    end)
    assert.is_true(result:is_err())

    local actual = result:unwrap_err()
    assert.are.same('Something went wrong Universe', actual.message)
  end)

  it('should flat_map a successful result', function()
    local result = Result.ok('Hello World'):flat_map(function(x)
      return Result.ok(x .. ' Universe')
    end)
    print(vim.inspect(result))

    assert.is_true(result:is_ok())
    assert.are.same('Hello World Universe', result:unwrap())
  end)

  it('should flat_map an unsuccessful result', function()
    local result = Result.err('Something went wrong'):flat_map(function(x)
      return Result.ok(x .. ' Universe')
    end)
    assert.is_true(result:is_err())

    local actual = result:unwrap_err()
    assert.are.same('Something went wrong', actual.message)
  end)

  it('should return error if flat_map function returns an error', function()
    local result = Result.ok('Something went wrong'):flat_map(function(x)
      return Result.err(x .. ' Universe')
    end)
    assert.is_true(result:is_err())

    local actual = result:unwrap_err()
    assert.are.same('Something went wrong Universe', actual.message)
  end)

  it('should chain successful results', function()
    local result = Result.ok('Hello World'):flat_map(function(x)
      return Result.ok(x .. ' Universe')
    end)
    assert.is_true(result:is_ok())
    assert.are.same('Hello World Universe', result:unwrap())
  end)

  it('should or_else a successful result', function()
    local result = Result.ok('Hello World'):or_else(function()
      return 'But fine!'
    end)
    assert.is.True(result:is_ok())
    assert.are.same('Hello World', result:unwrap())
  end)

  it('should or_else an error result', function()
    local result = Result.err('Something went wrong'):or_else(function()
      error('Something went wrong Universe')
    end)
    assert.is.True(result:is_err())

    local actual = result:unwrap_err().message
    assert.truthy(actual:find('Something went wrong Universe'))
  end)

  it('ok should convert to string representation', function()
    local result = Result.ok('Hello World')
    assert.are.same('Ok("Hello World")', tostring(result))
  end)

  it('error should convert to string representation', function()
    local result = Result.err('Something went wrong')
    assert.are.same('Err("Something went wrong")', tostring(result))
  end)

  it('should convert to string representation without an error', function()
    local result1 = Result.ok('Hello World')
    local result2 = Result.err('Something went wrong')

    print(result1:is_ok())  -- true
    print(result2:is_err()) -- true

    -- Chaining operations
    local final_result = Result.ok(5)
        :map(function(x) return x * 2 end)
        :map(tostring)

    if final_result:is_err() then
      print("Expected: 10, got: " .. final_result)
      assert.is.True(false)
    end
    local actual = final_result:unwrap()
    assert.are.same("10", actual)

    -- print("Type of final_result: " .. type(final_result))
    if type(actual) ~= 'string' then
      print("Expected: string, got: " .. type(actual))
      assert.is.True(false)
    end
    print("Expected: 10, got: " .. actual)
    assert.is.True(true)
  end)
end)
