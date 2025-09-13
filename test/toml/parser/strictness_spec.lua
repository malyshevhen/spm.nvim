describe('strictness setting', function()
  local TOML

  before_each(function() TOML = require('spm.vendor.toml') end)

  it('allows for mixed types in tables', function()
    TOML.strict = false
    local obj = TOML.parse([=[
mixed = [true, true, 3]]=])
    local sol = {
      mixed = { true, true, 3 },
    }
    assert.same(sol, obj)
  end)
end)
