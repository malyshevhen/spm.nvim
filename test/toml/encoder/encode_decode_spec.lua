describe('encoding', function()
  local TOML

  before_each(function() TOML = require('spm.vendor.toml') end)

  it('complex table', function()
    local tbl = {
      some_key = 10,
      hash = 'test_hash',
      plugins = {
        { name = 'test-plugin', src = 'https://github.com/test/plugin' },
      },
    }

    local encoded = TOML.encode(tbl)
    assert.not_nil(encoded)
    assert.is_string(encoded)
    print(type(encoded))

    -- Decode string back to Lua table
    local decoded = TOML.parse(encoded)
    assert.are.same(tbl, decoded)
  end)
end)
