local Path = require('plenary.path')
local fs = require('spm.lib.fs')

describe('fs', function()
  local temp_dir

  before_each(function()
    -- Create a temporary directory for each test
    local temp_path = Path:new(vim.fn.stdpath('cache'), 'spm-test-' .. vim.fn.rand())
    temp_dir = temp_path
    fs.mkdir(temp_dir.filename)
  end)

  after_each(function()
    -- Clean up the temporary directory
    temp_dir:rm({ force = true })
  end)

  describe('write_file and read_file', function()
    it('should write and read a file', function()
      local file_path = temp_dir:joinpath('test_file.txt').filename
      local content = 'hello world'

      local ok, write_err = fs.write_file(file_path, content)
      assert.is_true(ok)

      local read_content, read_err = fs.read_file(file_path)
      assert.is_nil(read_err)
      assert.is_string(read_content)
      assert.are.equal(content, read_content)
    end)

    it('should return an error when reading a non-existent file', function()
      local file_path = temp_dir:joinpath('non_existent.txt').filename
      local content, err = fs.read_file(file_path)
      assert.is_nil(content)
      assert.is_string(err)
    end)

    it('should return an error when writing with invalid content', function()
      local file_path = temp_dir:joinpath('test_file.txt').filename
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok, err = fs.write_file(file_path, nil)
      assert.is_nil(ok)
      assert.is_string(err)
    end)
  end)

  describe('delete_file', function()
    it('should delete a file', function()
      local file_path = temp_dir:joinpath('test_file.txt').filename
      fs.write_file(file_path, 'some content')

      local ok, err = fs.delete_file(file_path)
      assert.is_true(ok)

      -- Check that the file no longer exists
      local stat = vim.loop.fs_stat(file_path)
      assert.is_nil(stat)
    end)

    it('should return an error when deleting a non-existent file', function()
      local file_path = temp_dir:joinpath('non_existent.txt').filename
      local ok, err = fs.delete_file(file_path)
      assert.is_nil(ok)
      assert.is_string(err)
    end)
  end)

  describe('mkdir and rmdir', function()
    it('should create and remove a directory', function()
      local dir_path = temp_dir:joinpath('new_dir').filename

      local ok, mkdir_err = fs.mkdir(dir_path)
      assert.is_true(ok)

      -- Check that the directory exists
      local stat = vim.loop.fs_stat(dir_path)
      assert.is_table(stat)
      ---@diagnostic disable-next-line: need-check-nil
      assert.are.equal('directory', stat.type)

      local ok2, rmdir_err = fs.rmdir(dir_path)
      assert.is_true(ok2)

      -- Check that the directory no longer exists
      stat = vim.loop.fs_stat(dir_path)
      assert.is_nil(stat)
    end)

    it('should return an error when creating a directory that already exists', function()
      local dir_path = temp_dir:joinpath('new_dir').filename
      fs.mkdir(dir_path)

      local ok, err = fs.mkdir(dir_path)
      assert.is_nil(ok)
      assert.is_string(err)
    end)

    it('should return an error when removing a non-existent directory', function()
      local dir_path = temp_dir:joinpath('non_existent_dir').filename
      local ok, err = fs.rmdir(dir_path)
      assert.is_nil(ok)
      assert.is_string(err)
    end)
  end)
end)
