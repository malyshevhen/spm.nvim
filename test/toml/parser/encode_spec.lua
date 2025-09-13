describe('encoding', function()
  local TOML

  before_each(function() TOML = require('spm.vendor.toml') end)

  it('array', function()
    local obj = TOML.encode({ a = { 'foo', 'bar' } })
    local sol = 'a = ["foo", "bar"]'
    assert.same(sol, obj)
  end)
end)
