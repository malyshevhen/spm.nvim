local toml = require('spm.lib.toml.parser')

describe('TOML Parser', function()
  describe('Comments', function()
    it('should ignore full-line and inline comments', function()
      local toml_string = [[
        # This is a full-line comment
        key = "value" # This is an inline comment
      ]]
      local expected = { key = 'value' }
      assert.are.same(expected, toml.parse(toml_string))
    end)
  end)

  describe('Key-Value Pairs', function()
    it('parses basic keys', function()
      local toml_string = [[
        key = "value"
        bare_key = "value"
        bare-key = "value"
        _2_key = "value"
      ]]
      local expected = {
        key = 'value',
        bare_key = 'value',
        ['bare-key'] = 'value',
        ['_2_key'] = 'value',
      }
      assert.are.same(expected, toml.parse(toml_string))
    end)

    it('parses dotted keys', function()
      local toml_string = [[
        animal.type.name = "pug"
      ]]
      local expected = { animal = { type = { name = 'pug' } } }
      assert.are.same(expected, toml.parse(toml_string))
    end)
  end)

  describe('Data Types', function()
    describe('Strings', function()
      it('parses basic strings with escapes', function()
        local toml_string = 'str = "I\'m a string. \\"You can quote me\\". \\nNew line."'
        local expected = { str = 'I\'m a string. "You can quote me". \nNew line.' }
        assert.are.same(expected, toml.parse(toml_string))
      end)

      it('parses literal strings', function()
        local toml_string = [[ str = 'C:\Users\nougat.man\application.exe' ]]
        local expected = { str = 'C:\\Users\\nougat.man\\application.exe' }
        assert.are.same(expected, toml.parse(toml_string))
      end)

      it('parses multiline basic strings and trims the first newline', function()
        local toml_string = [[
          str = """
Roses are red
Violets are blue"""
        ]]
        local expected = { str = 'Roses are red\nViolets are blue' }
        assert.are.same(expected, toml.parse(toml_string))
      end)

      it('parses single-line multiline strings', function()
        local toml_string = [[ str = """A short sentence.""" ]]
        local expected = { str = 'A short sentence.' }
        assert.are.same(expected, toml.parse(toml_string))
      end)
    end)

    describe('Integers', function()
      it('parses positive, negative, and zero integers', function()
        local toml_string = 'int1 = 99\nint2 = -17\nint3 = 0'
        local expected = { int1 = 99, int2 = -17, int3 = 0 }
        assert.are.same(expected, toml.parse(toml_string))
      end)

      it('parses integers with underscores', function()
        local toml_string = 'int_with_underscores = 1_000_000'
        local expected = { int_with_underscores = 1000000 }
        assert.are.same(expected, toml.parse(toml_string))
      end)
    end)

    describe('Floats', function()
      it('parses fractional floats', function()
        local toml_string = 'flt1 = 1.0\nflt2 = -0.01'
        local expected = { flt1 = 1.0, flt2 = -0.01 }
        assert.are.same(expected, toml.parse(toml_string))
      end)

      it('parses exponential floats', function()
        local toml_string = [[
          exp1 = 5e+22
          exp2 = 1e6
          exp3 = -2E-2
          exp4 = 6.626e-34
        ]]
        local expected = { exp1 = 5e+22, exp2 = 1e6, exp3 = -0.02, exp4 = 6.626e-34 }
        assert.are.same(expected, toml.parse(toml_string))
      end)

      it('parses floats with underscores', function()
        local toml_string = 'flt_with_underscores = 9_224_617.445_991'
        local expected = { flt_with_underscores = 9224617.445991 }
        assert.are.same(expected, toml.parse(toml_string))
      end)

      it('parses special float values', function()
        local toml_string = [[
            sf1 = inf
            sf2 = +inf
            sf3 = -inf
            sf4 = nan
            sf5 = +nan
            sf6 = -nan
        ]]
        local result = toml.parse(toml_string)
        assert.is.equal(result.sf1, 1 / 0)
        assert.is.equal(result.sf2, 1 / 0)
        assert.is.equal(result.sf3, -1 / 0)
        assert.is.no.equal(result.sf4, result.sf4) -- The correct way to check for NaN
        assert.is.no.equal(result.sf5, result.sf5)
        assert.is.no.equal(result.sf6, result.sf6)
      end)
    end)

    describe('Booleans', function()
      it('parses true and false', function()
        local toml_string = 'bool1 = true\nbool2 = false'
        local expected = { bool1 = true, bool2 = false }
        assert.are.same(expected, toml.parse(toml_string))
      end)
    end)

    describe('Datetimes', function()
      it('parses datetimes as strings', function()
        local toml_string = [[
                odt = 1979-05-27T07:32:00Z
                ld = 1987-07-05
            ]]
        local expected = { odt = '1979-05-27T07:32:00Z', ld = '1987-07-05' }
        assert.are.same(expected, toml.parse(toml_string))
      end)
    end)
  end)

  describe('Arrays', function()
    it('parses an inline array of integers', function()
      local toml_string = 'points = [ 1, 2, 3 ]'
      local expected = { points = { 1, 2, 3 } }
      assert.are.same(expected, toml.parse(toml_string))
    end)

    it('parses an inline array of mixed types', function()
      local toml_string = 'data = [ "red", 123, true ]'
      local expected = { data = { 'red', 123, true } }
      assert.are.same(expected, toml.parse(toml_string))
    end)

    it('parses a multiline array', function()
      local toml_string = [[
        ports = [
          8001,
          8001,
          8002
        ]
      ]]
      local expected = { ports = { 8001, 8001, 8002 } }
      assert.are.same(expected, toml.parse(toml_string))
    end)

    it('parses an array with a trailing comma', function()
      local toml_string = "colors = [ 'red', 'yellow', 'green', ]"
      local expected = { colors = { 'red', 'yellow', 'green' } }
      assert.are.same(expected, toml.parse(toml_string))
    end)

    it('parses nested arrays', function()
      local toml_string = 'data = [ [ 1, 2 ], [3, 4, 5] ]'
      local expected = { data = { { 1, 2 }, { 3, 4, 5 } } }
      assert.are.same(expected, toml.parse(toml_string))
    end)
  end)

  describe('Tables', function()
    it('parses a simple table', function()
      local toml_string = [[
        [table]
        key = "value"
      ]]
      local expected = { table = { key = 'value' } }
      assert.are.same(expected, toml.parse(toml_string))
    end)

    it('parses dotted key tables', function()
      local toml_string = [[
        [dog.toby]
        type = "pug"
      ]]
      local expected = { dog = { toby = { type = 'pug' } } }
      assert.are.same(expected, toml.parse(toml_string))
    end)
  end)

  describe('Inline Tables', function()
    it('parses a simple inline table', function()
      local toml_string = 'point = { x = 1, y = 2 }'
      local expected = { point = { x = 1, y = 2 } }
      assert.are.same(expected, toml.parse(toml_string))
    end)

    it('parses an array of inline tables', function()
      local toml_string = [[
        points = [ { x = 1, y = 2, z = 3 },
                   { x = 7, y = 8, z = 9 } ]
      ]]
      local expected = {
        points = {
          { x = 1, y = 2, z = 3 },
          { x = 7, y = 8, z = 9 },
        },
      }
      assert.are.same(expected, toml.parse(toml_string))
    end)
  end)

  describe('Array of Tables', function()
    it('parses an array of tables', function()
      local toml_string = [=[
        [[products]]
        name = "Hammer"
        sku = 738594937

        [[products]]
        name = "Nail"
        sku = 284758393
      ]=]
      local expected = {
        products = {
          { name = 'Hammer', sku = 738594937 },
          { name = 'Nail', sku = 284758393 },
        },
      }
      assert.are.same(expected, toml.parse(toml_string))
    end)
  end)

  describe('Error Handling', function()
    it('errors on invalid syntax', function()
      local toml_string = 'this is not valid'
      assert.error_matches(function() toml.parse(toml_string) end, 'Invalid syntax')
    end)

    it('errors on key redefinition', function()
      local toml_string = 'key = 1\nkey = 2'
      assert.error_matches(
        function() toml.parse(toml_string) end,
        "Redefinition of key 'key' is not allowed"
      )
    end)

    it('errors on table redefinition', function()
      local toml_string = '[table]\n[table]'
      assert.error(
        function() toml.parse(toml_string) end,
        'TOML Parse Error (line 3): Redefinition of table `[table]` is not allowed.'
      )
    end)

    it('errors on unterminated multiline string', function()
      local toml_string = 'key = """'
      assert.error_matches(function() toml.parse(toml_string) end, 'Unterminated multiline string')
    end)

    it('errors on unterminated multiline array', function()
      local toml_string = 'key = [1, 2,'
      assert.error_matches(function() toml.parse(toml_string) end, 'Unterminated multiline array')
    end)
  end)
end)
