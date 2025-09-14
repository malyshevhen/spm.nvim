describe('float parsing', function()
  local TOML

  before_each(function() TOML = require('spm.lib.toml') end)

  it('float', function()
    local obj = TOML.parse([=[
pi = 3.14
negpi = -3.14
pluspi = +3.14]=])
    local sol = {
      pi = 3.14,
      negpi = -3.14,
      pluspi = 3.14,
    }
    assert.same(sol, obj)
  end)

  it('long', function()
    local obj = TOML.parse([=[
longpi = 3.141592653589793
neglongpi = -3.141592653589793]=])
    local sol = {
      longpi = 3.141592653589793,
      neglongpi = -3.141592653589793,
    }
    assert.same(sol, obj)
  end)

  it('exponent', function()
    local input = [=[exp1 = 5e+22
exp2 = 1e6
exp3 = -2E-2
exp4 = 6.626e-34]=]
    print('TOML input: \n', input)
    local obj = TOML.parse(input)
    local sol = {
      exp1 = 5e+22,
      exp2 = 1e6,
      exp3 = -2e-2,
      exp4 = 6.626e-34,
    }
    assert.same(sol, obj)
  end)

  it('underscore', function()
    local obj = TOML.parse([=[
underscore = 9_224_617.445_991]=])
    local sol = {
      underscore = 9224617.445991,
    }
    assert.same(sol, obj)
  end)
end)
