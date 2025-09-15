local crypto = require('spm.lib.crypto')

describe('crypto', function()
  it('should generate a sha256 hash for a string', function()
    local hash, err = crypto.generate_hash('test')
    assert.is_nil(err)
    assert.is_string(hash)
    assert.are.same(
      '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
      hash
    )
  end)

  it('should return an error if the content is not a string', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local hash, err = crypto.generate_hash(123)
    assert.is_nil(hash)
    assert.is_string(err)
  end)
end)
