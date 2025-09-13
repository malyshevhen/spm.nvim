describe('boolean parsing', function()
  local TOML

  before_each(function() TOML = require('spm.vendor.toml') end)

  it('boolean', function()
    local obj = TOML.parse([=[
t = true
f = false]=])
    local sol = {
      t = true,
      f = false,
    }
    assert.same(sol, obj)
  end)
end)
