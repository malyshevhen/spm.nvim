local toml = require('spm.lib.toml')

describe('lib.toml', function()
  describe('encode', function()
    it('should encode a lua table to a toml string', function()
      local tbl = {
        test = 'value',
      }
      local encoded, err = toml.encode(tbl)
      assert.is_nil(err)
      assert.is_string(encoded)
      assert.are.same('test = "value"', encoded)
    end)

    it('should return an error if the input is not a table', function()
      ---@diagnostic disable-next-line: param-type-mismatch
      local encoded, err = toml.encode('not a table')

      assert.is_nil(encoded)
      assert.is_string(err)
    end)
  end)
end)
