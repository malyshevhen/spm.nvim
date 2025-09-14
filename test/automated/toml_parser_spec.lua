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
    local result = toml_parser.encode(tbl)
    assert.is_true(result:is_ok())
    assert.are.same('test = "value"', result:unwrap())
  end)

  it('should return an error if the input is not a table', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local result = toml_parser.encode('not a table')

    assert.is_true(result:is_err())
    assert.are.same('Input must be a table', result.error.message)
  end)
end)
