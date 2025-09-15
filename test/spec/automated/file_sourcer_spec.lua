---@diagnostic disable: need-check-nil
local file_sourcer = require('spm.lib.file_sourcer')

describe('file_sourcer', function()
  before_each(function()
    vim.fn.mkdir('test/spec/fixtures/file_sourcer', 'p')
    vim.fn.mkdir('test/spec/fixtures/file_sourcer/nested', 'p')
  end)

  after_each(function() vim.fn.delete('test/spec/fixtures/file_sourcer', 'rf') end)

  it('should source a lua file', function()
    local file = io.open('test/spec/fixtures/file_sourcer/test.lua', 'w')
    file:write('return true')
    file:close()

    local ok, err = file_sourcer.source_lua_file('test/spec/fixtures/file_sourcer/test.lua')
    assert.is_true(ok)
    assert.is_nil(err)
  end)

  it('should return an error if the file is not readable', function()
    local ok, err = file_sourcer.source_lua_file('test/spec/fixtures/file_sourcer/non_existent.lua')
    assert.is_nil(ok)
    assert.is_string(err)
  end)

  it('should return an error if the file has a syntax error', function()
    local file = io.open('test/spec/fixtures/file_sourcer/syntax_error.lua', 'w')
    file:write('this is a syntax error')
    file:close()

    local ok, err = file_sourcer.source_lua_file('test/spec/fixtures/file_sourcer/syntax_error.lua')
    assert.is_nil(ok)
    assert.is_string(err)
    assert.truthy(err:find('Error sourcing test/spec/fixtures/file_sourcer/syntax_error.lua'))
  end)

  it('should return a list of lua files in a directory', function()
    local file = io.open('test/spec/fixtures/file_sourcer/test1.lua', 'w')
    file:write('return true')
    file:close()

    file = io.open('test/spec/fixtures/file_sourcer/test2.lua', 'w')
    file:write('return true')
    file:close()

    local files = file_sourcer.get_lua_files('test/spec/fixtures/file_sourcer', false)
    assert.are.same(2, #files)
  end)

  it('should return a list of lua files in a directory recursively', function()
    local file = io.open('test/spec/fixtures/file_sourcer/test1.lua', 'w')
    file:write('return true')
    file:close()

    file = io.open('test/spec/fixtures/file_sourcer/nested/test2.lua', 'w')
    file:write('return true')
    file:close()

    local files = file_sourcer.get_lua_files('test/spec/fixtures/file_sourcer', true)
    assert.are.same(2, #files)
  end)

  it('should return an empty list if the directory does not exist', function()
    local files = file_sourcer.get_lua_files('test/spec/fixtures/file_sourcer/non_existent', false)
    assert.are.same(0, #files)
  end)

  it('should source all lua files in a directory', function()
    local file = io.open('test/spec/fixtures/file_sourcer/test1.lua', 'w')
    file:write('return true')
    file:close()

    file = io.open('test/spec/fixtures/file_sourcer/test2.lua', 'w')
    file:write('return true')
    file:close()

    local result, err =
      file_sourcer:source_directory('test/spec/fixtures/file_sourcer', { recursive = false })
    assert.is_nil(err)
    assert.is_table(result)
    assert.are.same(2, result.files_sourced)
  end)

  it('should return an error if any of the files have a syntax error', function()
    local file = io.open('test/spec/fixtures/file_sourcer/test1.lua', 'w')
    file:write('return true')
    file:close()

    file = io.open('test/spec/fixtures/file_sourcer/syntax_error.lua', 'w')
    file:write('this is a syntax error')
    file:close()

    local result, err =
      file_sourcer:source_directory('test/spec/fixtures/file_sourcer', { recursive = false })
    assert.is_nil(result)
    assert.is_string(err)
  end)
end)
