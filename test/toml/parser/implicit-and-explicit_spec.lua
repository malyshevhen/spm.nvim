describe('implicit and explicit', function()
  local TOML

  before_each(function() TOML = require('spm.vendor.toml') end)

  it('groups', function()
    local obj = TOML.parse([=[
[a.b.c]
answer = 42]=])
    local sol = {
      a = {
        b = {
          c = {
            answer = 42,
          },
        },
      },
    }
    assert.same(sol, obj)
  end)

  it('after', function()
    local obj = TOML.parse([=[
[a.b.c]
answer = 42

[a]
better = 43]=])
    local sol = {
      a = {
        better = 43,
        b = {
          c = {
            answer = 42,
          },
        },
      },
    }
    assert.same(sol, obj)
  end)

  it('before', function()
    local obj = TOML.parse([=[
[a]
better = 43

[a.b.c]
answer = 42
		]=])
    local sol = {
      a = {
        better = 43,
        b = {
          c = {
            answer = 42,
          },
        },
      },
    }
    assert.same(sol, obj)
  end)
end)
