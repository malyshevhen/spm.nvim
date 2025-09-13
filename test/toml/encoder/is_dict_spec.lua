-- /home/evhen/projects/spm.nvim/test/toml/encoder/is_dict_spec.lua
local encoder = require('spm.lib.encoder')

describe('encoder._is_dict', function()
  it('should return true for a dictionary', function()
    assert.is_true(encoder._is_dict({ a = 1, b = 2 }))
  end)

  it('should return true for a dictionary with table values', function()
    assert.is_true(encoder._is_dict({ a = {}, b = {} }))
  end)

  it('should return true for an empty table', function()
    assert.is_true(encoder._is_dict({}))
  end)

  it('should return false for an array', function()
    assert.is_false(encoder._is_dict({ 1, 2, 3 }))
  end)

  it('should return false for a mixed table', function()
    assert.is_false(encoder._is_dict({ 1, 2, a = 3 }))
  end)

  it('should return false for non-table input', function()
    assert.is_false(encoder._is_dict(123))
    assert.is_false(encoder._is_dict("hello"))
    assert.is_false(encoder._is_dict(nil))
  end)
end)