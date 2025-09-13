describe('empty parsing', function()
  local TOML

  before_each(function() TOML = require('spm.vendor.toml') end)

  it('empty', function()
    local obj = TOML.parse('')
    local sol = {}
    assert.same(sol, obj)
  end)
end)
