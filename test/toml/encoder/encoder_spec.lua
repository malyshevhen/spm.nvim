local encoder = require('spm.lib.encoder')

describe('TOML Encoder', function()
  describe('SYMBOL constants', function()
    it('should have all required symbols', function()
      local SYMBOL = encoder._SYMBOL
      assert.are.equal("'", SYMBOL.SINGLE_QUOTE)
      assert.are.equal('"', SYMBOL.DOUBLE_QUOTE)
      assert.are.equal('"""', SYMBOL.MULTI_LINE_QUOTE)
      assert.are.equal('[', SYMBOL.SINGE_OPEN_BRACKET)
      assert.are.equal('[[', SYMBOL.DOUBLE_OPEN_BRACKET)
      assert.are.equal(']', SYMBOL.SINGE_CLOSE_BRACKET)
      assert.are.equal(']]', SYMBOL.DOUBLE_CLOSE_BRACKET)
      assert.are.equal('{', SYMBOL.SINGE_OPEN_BRACE)
      assert.are.equal('}', SYMBOL.SINGE_CLOSE_BRACE)
      assert.are.equal(' ', SYMBOL.SPACE)
      assert.are.equal('=', SYMBOL.EQUALS)
      assert.are.equal('.', SYMBOL.PERIOD)
      assert.are.equal(',', SYMBOL.COMMA)
      assert.are.equal('\n', SYMBOL.NEWLINE)
    end)

    it('should be read-only', function()
      local SYMBOL = encoder._SYMBOL
      assert.has_error(
        function() SYMBOL.NEW_SYMBOL = 'test' end,
        'Attempt to modify read-only table'
      )
    end)
  end)

  describe('read_only function', function()
    it('should create a read-only table', function()
      local original = { a = 1, b = 2 }
      local readonly = encoder._read_only(original)

      -- Should be able to read
      assert.are.equal(1, readonly.a)
      assert.are.equal(2, readonly.b)

      -- Should not be able to modify
      assert.has_error(function() readonly.c = 3 end, 'Attempt to modify read-only table')
    end)
  end)

  describe('split_key function', function()
    it('should split key correctly', function()
      local new_key, sub_key = encoder._split_key('foo.bar.baz')
      assert.are.equal('foo.bar', new_key)
      assert.are.equal('baz', sub_key)
    end)

    it('should handle single key', function()
      local new_key, sub_key = encoder._split_key('foo')
      assert.are.equal('foo', new_key)
      assert.are.equal('', sub_key)
    end)

    it('should handle two-part key', function()
      local new_key, sub_key = encoder._split_key('foo.bar')
      assert.are.equal('foo', new_key)
      assert.are.equal('bar', sub_key)
    end)
  end)

  describe('is_array function', function()
    it('should detect empty array', function()
      local is_arr, is_values_tables = encoder._is_array({})
      assert.is_false(is_arr)
      assert.is_false(is_values_tables)
    end)

    it('should detect array of primitives', function()
      local is_arr, is_values_tables = encoder._is_array({ 1, 2, 3 })
      assert.is_true(is_arr)
      assert.is_false(is_values_tables)
    end)

    it('should detect array of tables', function()
      local is_arr, is_values_tables = encoder._is_array({ { a = 1 }, { b = 2 } })
      assert.is_true(is_arr)
      assert.is_true(is_values_tables)
    end)

    it('should detect non-array', function()
      local is_arr, is_values_tables = encoder._is_array({ a = 1, b = 2 })
      assert.is_false(is_arr)
      assert.is_true(is_values_tables)
    end)

    it('should handle non-table input', function()
      local is_arr, is_values_tables = encoder._is_array('not a table')
      assert.is_false(is_arr)
      assert.is_false(is_values_tables)
    end)

    it('should throw error for mixed table', function()
      assert.has_error(
        function() encoder._is_array({ 1, 2, a = 'mixed' }) end,
        'Mixed table format, input is corrupted'
      )
    end)
  end)

  describe('is_dict function', function()
    it(
      'should detect dictionary',
      function() assert.is_true(encoder._is_dict({ a = 1, b = 2 })) end
    )

    it('should detect empty dictionary', function() assert.is_true(encoder._is_dict({})) end)

    it(
      'should not detect array as dictionary',
      function() assert.is_false(encoder._is_dict({ 1, 2, 3 })) end
    )

    it(
      'should handle non-table input',
      function() assert.is_false(encoder._is_dict('not a table')) end
    )

    it(
      'should not detect mixed table as dictionary',
      function() assert.is_false(encoder._is_dict({ 1, 2, a = 'mixed' })) end
    )
  end)

  describe('parse_string function', function()
    it('should wrap simple string in single quotes', function()
      local result = encoder._parse_string('hello')
      assert.are.equal("'hello'", result)
    end)

    it('should escape backslashes', function()
      local result = encoder._parse_string('path\\to\\file')
      assert.are.equal("'path\\to\\file'", result)
    end)

    it('should use multiline quotes for strings with newlines', function()
      local result = encoder._parse_string('line1\nline2')
      assert.are.equal('"""line1\nline2"""', result)
    end)

    it('should handle string starting with newline', function()
      local result = encoder._parse_string('\nhello')
      assert.are.equal('"""\nhello"""', result)
    end)

    it('should escape special characters', function()
      local result = encoder._parse_string('test\b\t\f\r')
      assert.are.equal("'test\b\t\f\r'", result)
    end)
  end)

  describe('parse_array_flat function', function()
    it('should handle empty array', function()
      local result = encoder._parse_array_flat({})
      assert.are.equal('', result)
    end)

    it('should parse array of numbers', function()
      local result = encoder._parse_array_flat({ 1, 2, 3 })
      assert.are.equal('1, 2, 3\n', result)
    end)

    it('should parse array of strings', function()
      local result = encoder._parse_array_flat({ 'a', 'b', 'c' })
      assert.are.equal("'a', 'b', 'c'\n", result)
    end)

    it('should parse array of booleans', function()
      local result = encoder._parse_array_flat({ true, false })
      assert.are.equal('true, false\n', result)
    end)
  end)

  describe('parse_dict_flat function', function()
    it('should parse simple dictionary', function()
      local result = encoder._parse_dict_flat({ a = 1, b = 2 })
      -- Note: order might vary due to sorting
      assert.is_true(
        result:match('{ .*a = 1.*b = 2.* }\n') or result:match('{ .*b = 2.*a = 1.* }\n')
      )
    end)

    it('should parse dictionary with strings', function()
      local result = encoder._parse_dict_flat({ name = 'test' })
      assert.are.equal("{ name = 'test' }\n", result)
    end)
  end)

  describe('group_by_depth_and_keys function', function()
    it('should group simple nested structure', function()
      local input = {
        foo = {
          bar = {
            baz = 1,
            qux = {
              zap = 42,
            },
          },
        },
      }

      local result = encoder._group_by_depth_and_keys(input)
      assert.no_nil(result[1])

      -- Should have grouped keys by depth
      local found_baz = false
      local found_zap = false

      for depth, group in ipairs(result) do
        for key, value in pairs(group) do
          if key == 'foo.bar.baz' and value == 1 then
            found_baz = true
          elseif key == 'foo.bar.qux.zap' and value == 42 then
            found_zap = true
          end
        end
      end

      assert.is_true(found_baz)
      assert.is_true(found_zap)
    end)

    it('should handle empty table', function()
      local result = encoder._group_by_depth_and_keys({})
      assert.no_nil(result[1])
      assert.are.same({}, result[1])
    end)

    it('should handle flat structure', function()
      local input = { a = 1, b = 2 }
      local result = encoder._group_by_depth_and_keys(input)

      assert.are.equal(1, result[1].a)
      assert.are.equal(2, result[1].b)
    end)
  end)

  describe('normalize_by_keys function', function()
    it('should normalize grouped keys', function()
      local input = {
        [1] = { a = 1, b = 2 },
        [2] = { ['c.d'] = 3 },
      }

      local result = encoder._normalize_by_keys(input)
      assert.are.equal(1, result.a)
      assert.are.equal(2, result.b)
      assert.are.equal(3, result.c.d)
    end)

    it('should handle single depth', function()
      local input = {
        [1] = { a = 1, b = 2 },
      }

      local result = encoder._normalize_by_keys(input)
      assert.are.equal(1, result.a)
      assert.are.equal(2, result.b)
    end)
  end)

  describe('encode function', function()
    it('should encode simple table', function()
      local input = {
        title = 'Test',
        value = 42,
        flag = true,
      }

      local result = encoder.encode(input)
      assert.is_string(result)
      assert.is_true(result:find('title'))
      assert.is_true(result:find('value'))
      assert.is_true(result:find('flag'))
    end)

    it('should handle nested tables', function()
      local input = {
        database = {
          host = 'localhost',
          port = 5432,
          credentials = {
            username = 'admin',
            password = 'secret',
          },
        },
      }

      local result = encoder.encode(input)
      assert.is_string(result)
      assert.is_true(result:find('database'))
      assert.is_true(result:find('host'))
      assert.is_true(result:find('credentials'))
    end)

    it('should handle arrays', function()
      local input = {
        numbers = { 1, 2, 3, 4, 5 },
        strings = { 'a', 'b', 'c' },
      }

      local result = encoder.encode(input)
      assert.is_string(result)
      assert.is_true(result:find('numbers'))
      assert.is_true(result:find('strings'))
    end)

    it('should throw error for invalid input', function()
      assert.has_error(function() encoder.encode('not a table') end)
    end)

    it('should throw error for array input', function()
      assert.has_error(
        function() encoder.encode({ 1, 2, 3 }) end,
        'Only tables with a key-value structure are supported'
      )
    end)
  end)

  describe('integration tests', function()
    it('should encode complex nested structure', function()
      local input = {
        title = 'TOML Example',

        owner = {
          name = 'Tom Preston-Werner',
          dob = '1979-05-27T15:32:00-08:00',
        },

        database = {
          server = '192.168.1.1',
          ports = { 8001, 8001, 8002 },
          connection_max = 5000,
          enabled = true,
        },

        servers = {
          alpha = {
            ip = '10.0.0.1',
            dc = 'eqdc10',
          },
          beta = {
            ip = '10.0.0.2',
            dc = 'eqdc10',
          },
        },
      }

      local result = encoder.encode(input)
      assert.is_string(result)

      -- Check for key sections
      assert.is_true(result:find('title'))
      assert.is_true(result:find('owner'))
      assert.is_true(result:find('database'))
      assert.is_true(result:find('servers'))

      -- Check for nested values
      assert.is_true(result:find('Tom Preston%-Werner'))
      assert.is_true(result:find('192%.168%.1%.1'))
      assert.is_true(result:find('10%.0%.0%.1'))
    end)

    it('should handle edge case with empty nested tables', function()
      local input = {
        empty = {},
        nested = {
          also_empty = {},
        },
      }

      local result = encoder.encode(input)
      assert.is_string(result)
    end)

    it('should handle mixed data types', function()
      local input = {
        string_val = 'hello',
        number_val = 42,
        boolean_val = true,
        array_val = { 1, 2, 3 },
        nested_val = {
          inner = 'value',
        },
      }

      local result = encoder.encode(input)
      assert.is_string(result)
      assert.is_true(result:find('hello'))
      assert.is_true(result:find('42'))
      assert.is_true(result:find('true'))
      assert.is_true(result:find('value'))
    end)
  end)

  describe('error handling', function()
    it('should handle corrupted mixed tables gracefully', function()
      -- This test depends on the specific implementation details
      -- and might need adjustment based on how the encoder handles edge cases
      local problematic_input = {
        mixed = { 1, 2, key = 'value' }, -- This should trigger the mixed table error
      }

      assert.has_error(function() encoder.encode(problematic_input) end)
    end)
  end)
end)
