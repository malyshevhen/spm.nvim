-- /home/evhen/projects/spm.nvim/test/toml/encoder/parse_string_spec.lua
local encoder = require('spm.lib.encoder')

describe('encoder._parse_string', function()
  it(
    'should wrap a simple string in single quotes',
    function() assert.are.equal("'hello'", encoder._parse_string('hello')) end
  )

  it(
    'should escape backslashes',
    function() assert.are.equal("'hello\\world'", encoder._parse_string('helloworld')) end
  )

  it(
    'should use multiline quotes for strings with newlines',
    function() assert.are.equal('"""hello\nworld"""', encoder._parse_string('hello\nworld')) end
  )

  it(
    'should use multiline quotes for strings starting with a newline and escape it',
    function() assert.are.equal('"""\\n\nworld"""', encoder._parse_string('\nworld')) end
  )

  it(
    'should escape special characters',
    function() assert.are.equal("'\\b\\t\\f\\r'", encoder._parse_string('\b\t\f\r')) end
  )

  it(
    'should not escape double quotes in single quoted strings',
    function() assert.are.equal("'hello\"world'", encoder._parse_string('hello"world')) end
  )

  it('should handle empty string', function() assert.are.equal("''", encoder._parse_string('')) end)
end)
