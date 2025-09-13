-- /home/evhen/projects/spm.nvim/test/toml/encoder/is_array_spec.lua
local encoder = require('spm.lib.encoder')

describe('encoder._is_array', function()
  it('should return true for an array of primitives', function()
    local is_a = encoder._is_array({ 1, 2, 3 })
    assert.is_true(is_a)
  end)

  it('should return true for an array of tables', function()
    local is_a = encoder._is_array({ {}, {} })
    assert.is_true(is_a)
  end)

  it('should return true for an array of mixed primitives and tables', function()
    local is_a = encoder._is_array({ 1, {} })
    assert.is_true(is_a)
  end)

  it('should return false for a dictionary', function()
    local is_a = encoder._is_array({ a = 1, b = 2 })
    assert.is_false(is_a)
  end)

  it('should return false for an empty table', function()
    local is_a = encoder._is_array({})
    assert.is_false(is_a)
  end)

  it('should return false for non-table input', function()
    local is_a, is_t
    is_a = encoder._is_array(123)
    assert.is_false(is_a)

    is_a = encoder._is_array('hello')
    assert.is_false(is_a)

    is_a = encoder._is_array(nil)
    assert.is_false(is_a)
  end)
end)

