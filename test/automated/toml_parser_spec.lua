local toml_parser = require('spm.lib.toml_parser')

describe('toml_parser', function()
  -- Skipping parsing tests to focus on encoding
  -- it('should parse a valid toml file', function()
  --   ...
  -- end)

  -- it('should return an error if the file is not a valid toml file', function()
  --   ...
  -- end)

  it('should encode a lua table to a toml string', function()
    local tbl = {
      test = 'value',
    }
    local encoded, err = toml_parser.encode(tbl)
    assert.is_nil(err)
    assert.is_string(encoded)
    assert.are.same('test = "value"', encoded)
  end)

  it('should return an error if the input is not a table', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local encoded, err = toml_parser.encode('not a table')

    assert.is_nil(encoded)
    assert.is_string(err)
  end)
end)
