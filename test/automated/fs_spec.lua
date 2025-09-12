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

      local write_result = fs.write_file(file_path, content)
      assert.is_true(write_result:is_ok())

      local read_result = fs.read_file(file_path)
      assert.is_true(read_result:is_ok())
      assert.are.equal(content, read_result:unwrap())
    end)

    it('should return an error when reading a non-existent file', function()
      local file_path = temp_dir:joinpath('non_existent.txt').filename
      local result = fs.read_file(file_path)
      assert.is_true(result:is_err())
    end)

    it('should return an error when writing with invalid content', function()
      local file_path = temp_dir:joinpath('test_file.txt').filename
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = fs.write_file(file_path, nil)
      assert.is_true(result:is_err())
    end)
  end)

  describe('delete_file', function()
    it('should delete a file', function()
      local file_path = temp_dir:joinpath('test_file.txt').filename
      fs.write_file(file_path, 'some content')

      local delete_result = fs.delete_file(file_path)
      assert.is_true(delete_result:is_ok())

      -- Check that the file no longer exists
      local stat = vim.loop.fs_stat(file_path)
      assert.is_nil(stat)
    end)

    it('should return an error when deleting a non-existent file', function()
      local file_path = temp_dir:joinpath('non_existent.txt').filename
      local result = fs.delete_file(file_path)
      assert.is_true(result:is_err())
    end)
  end)

  describe('mkdir and rmdir', function()
    it('should create and remove a directory', function()
      local dir_path = temp_dir:joinpath('new_dir').filename

      local mkdir_result = fs.mkdir(dir_path)
      assert.is_true(mkdir_result:is_ok())

      -- Check that the directory exists
      local stat = vim.loop.fs_stat(dir_path)
      assert.is_table(stat)
      ---@diagnostic disable-next-line: need-check-nil
      assert.are.equal('directory', stat.type)

      local rmdir_result = fs.rmdir(dir_path)
      assert.is_true(rmdir_result:is_ok())

      -- Check that the directory no longer exists
      stat = vim.loop.fs_stat(dir_path)
      assert.is_nil(stat)
    end)

    it('should return an error when creating a directory that already exists', function()
      local dir_path = temp_dir:joinpath('new_dir').filename
      fs.mkdir(dir_path)

      local result = fs.mkdir(dir_path)
      assert.is_true(result:is_err())
    end)

    it('should return an error when removing a non-existent directory', function()
      local dir_path = temp_dir:joinpath('non_existent_dir').filename
      local result = fs.rmdir(dir_path)
      assert.is_true(result:is_err())
    end)
  end)
end)
