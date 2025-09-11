local crypto = require('spm.crypto')

describe('crypto', function()
  it('should generate a sha256 hash for a string', function()
    local result = crypto.generate_hash('test')
    assert.is_true(result:is_ok())
    assert.are.same(
      '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
      result:unwrap()
    )
  end)

  it('should return an error if the content is not a string', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local result = crypto.generate_hash(123)
    assert.is_true(result:is_err())
    assert.are.same('Content must be a string', result.error.message)
  end)
end)
