-- /home/evhen/projects/spm.nvim/test/toml/encoder/read_only_spec.lua
local encoder = require('spm.lib.encoder')

describe('encoder._read_only', function()
  it('should make a table read-only', function()
    local original_table = { a = 1, b = 2 }
    local read_only_table = encoder._read_only(original_table)

    -- Test reading from the table
    assert.are.equal(1, read_only_table.a)
    assert.are.equal(2, read_only_table.b)

    -- Test writing to the table, which should error
    assert.has_error(function()
      read_only_table.c = 3
    end, 'Attempt to modify read-only table')
  end)

  it('should not allow changing the metatable', function()
    local original_table = { a = 1 }
    local read_only_table = encoder._read_only(original_table)
    assert.is_false(getmetatable(read_only_table))
  end)

  it('should work with nested tables (non-recursively)', function()
    local original_table = { a = { b = 2 } }
    local read_only_table = encoder._read_only(original_table)
    assert.are.same({ b = 2 }, read_only_table.a)
    -- The read_only function is not recursive, so nested tables are still mutable.
    read_only_table.a.c = 3
    assert.are.equal(3, read_only_table.a.c)
  end)
end)