describe('datetime parsing', function()
  local TOML

  before_each(function() TOML = require('spm.lib.toml') end)

  it('datetime', function()
    local obj = TOML.parse([=[
bestdayever = 1987-07-05T17:45:00Z]=])
    local sol = {
      bestdayever = '1987-07-05T17:45:00Z',
    }
    assert.same(sol, obj)
  end)
end)
