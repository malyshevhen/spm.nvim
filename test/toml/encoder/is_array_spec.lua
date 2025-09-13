-- /home/evhen/projects/spm.nvim/test/toml/encoder/is_array_spec.lua
local encoder = require('spm.lib.encoder')

describe('encoder._is_array', function()
  it('should return true for an array of primitives', function()
    local is_a, is_t = encoder._is_array({ 1, 2, 3 })
    assert.is_true(is_a)
    assert.is_false(is_t)
  end)

  it('should return true for an array of tables', function()
    local is_a, is_t = encoder._is_array({ {}, {} })
    assert.is_true(is_a)
    assert.is_true(is_t)
  end)

  it('should return true for an array of mixed primitives and tables', function()
    local is_a, is_t = encoder._is_array({ 1, {} })
    assert.is_true(is_a)
    assert.is_false(is_t)
  end)

  it('should return false for a dictionary', function()
    local is_a, is_t = encoder._is_array({ a = 1, b = 2 })
    assert.is_false(is_a)
    assert.is_false(is_t)
  end)

  it('should return false for an empty table', function()
    local is_a, is_t = encoder._is_array({})
    assert.is_false(is_a)
    assert.is_false(is_t)
  end)

  it('should throw an error for a mixed table (array and dict)', function()
    -- Note: This test is expected to fail with the current implementation,
    -- as the function does not correctly handle mixed tables and throws no error.
    -- It returns (false, true) instead.
    assert.has_error(function()
      encoder._is_array({ 1, 2, a = 3 })
    end, 'Mixed table format, input is corrupted')
  end)

  it('should return false for non-table input', function()
    local is_a, is_t
    is_a, is_t = encoder._is_array(123)
    assert.is_false(is_a)
    assert.is_false(is_t)

    is_a, is_t = encoder._is_array("hello")
    assert.is_false(is_a)
    assert.is_false(is_t)

    is_a, is_t = encoder._is_array(nil)
    assert.is_false(is_a)
    assert.is_false(is_t)
  end)
end)