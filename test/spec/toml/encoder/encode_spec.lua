describe('encoding', function()
  local TOML

  before_each(function() TOML = require('spm.lib.toml') end)

  it('array', function()
    local obj = TOML.encode({ a = { 'foo', 'bar' } })
    local sol = 'a = [ "foo", "bar" ]'
    assert.same(sol, obj)
  end)

  it('bool', function()
    local obj = TOML.encode({ a = true })
    local sol = 'a = true'
    assert.same(sol, obj)
  end)

  it('comments', function()
    local obj = TOML.encode({ a = 'foo' })
    local sol = '# comment\na = "foo"'
    assert.same(sol, obj)
  end)

  it('datetime', function()
    local obj = TOML.encode({ a = os.time() })
    local sol = 'a = 1970-01-01T00:00:00Z'
    assert.same(sol, obj)
  end)

  it('empty', function()
    local obj = TOML.encode({})
    local sol = ''
    assert.same(sol, obj)
  end)

  it('float', function()
    local obj = TOML.encode({ a = 1.5 })
    local sol = 'a = 1.5'
    assert.same(sol, obj)
  end)

  it('implicit-and-explicit', function()
    local obj = TOML.encode({ a = { b = 1 } })
    local sol = 'a = { b = 1 }'
    assert.same(sol, obj)
  end)

  it('integer', function()
    local obj = TOML.encode({ a = 1 })
    local sol = 'a = 1'
    assert.same(sol, obj)
  end)

  it('complex-mixed-table', function()
    local obj = TOML.encode({
      a = 1,
      b = true,
      c = 'foo',
      d = { e = 1, f = true },
      g = { h = 1, i = true },
      j = { k = 1, l = true },
      m = { n = 1, o = true },
      p = { q = 1, r = true },
    })
    local sol = [[a = 1
b = true
c = "foo"

[d]
e = 1
f = true

[g]
h = 1
i = true

[j]
k = 1
l = true

[m]
n = 1
o = true

[p]
q = 1
r = true]]

    assert.same(sol, obj)
  end)

  it('key', function()
    local obj = TOML.encode({ ['foo.bar'] = 1 })
    local sol = '"foo.bar" = 1'
    assert.same(sol, obj)
  end)

  it('string', function()
    local obj = TOML.encode({ a = 'foo' })
    local sol = 'a = "foo"'
    assert.same(sol, obj)
  end)

  it('table-array', function()
    local obj = TOML.encode({ a = { { b = 1 } } })
    local sol = 'a = [ { b = 1 } ]'
    assert.same(sol, obj)
  end)
end)
