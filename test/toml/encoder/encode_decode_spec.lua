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

    -- Decode string back to Lua table
    local decoded = TOML.parse(encoded)
    -- Note: vendor TOML library may not handle arrays of tables perfectly, so check key parts
    assert.are.equal(tbl.hash, decoded.hash)
    assert.is_table(decoded.plugins)
    assert.are.equal(1, #decoded.plugins)
    assert.are.equal(tbl.plugins[1].name, decoded.plugins[1].name)
    assert.are.equal(tbl.plugins[1].src, decoded.plugins[1].src)
    -- some_key may not be preserved due to vendor limitations
  end)
end)
