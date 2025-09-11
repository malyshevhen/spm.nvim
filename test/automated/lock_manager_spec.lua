---@diagnostic disable: need-check-nil
local lock_manager = require('spm.lock_manager')
local crypto = require('spm.crypto')

describe('lock_manager', function()
  local lock_file_path = 'test/fixtures/spm.lock'

  after_each(function() os.remove(lock_file_path) end)

  it('should read and parse a lock file', function()
    local lock_data = {
      hash = 'test_hash',
    }
    local result = lock_manager.write(lock_file_path, lock_data)
    assert.is_true(result:is_ok())

    local read_result = lock_manager.read(lock_file_path)
    assert.is_true(read_result:is_ok())
    assert.are.same(lock_data, read_result:unwrap())
  end)

  it('should return nil if the lock file does not exist', function()
    local read_result = lock_manager.read(lock_file_path)
    assert.is_true(read_result:is_ok())
    assert.is_nil(read_result:unwrap())
  end)

  it('should write data to a lock file', function()
    local lock_data = {
      hash = 'test_hash',
    }
    local result = lock_manager.write(lock_file_path, lock_data)
    assert.is_true(result:is_ok())

    local file = io.open(lock_file_path, 'r')
    assert.are.not_nil(file)
    file:close()
  end)

  it('should return true if the lock file is stale', function()
    local plugins_toml_content = 'test content'
    local lock_data = {
      hash = 'wrong_hash',
    }
    local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)
    assert.is_true(is_stale)
  end)

  it('should return false if the lock file is not stale', function()
    local plugins_toml_content = 'test content'
    local hash_result = crypto.generate_hash(plugins_toml_content)
    local lock_data = {
      hash = hash_result:unwrap(),
    }
    local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)
    assert.is_false(is_stale)
  end)

  it('should return true if the lock file does not exist', function()
    local plugins_toml_content = 'test content'
    local is_stale = lock_manager.is_stale(plugins_toml_content, nil)
    assert.is_true(is_stale)
  end)

  it('should return true if the lock file does not have a hash', function()
    local plugins_toml_content = 'test content'
    local lock_data = {}
    local is_stale = lock_manager.is_stale(plugins_toml_content, lock_data)
    assert.is_true(is_stale)
  end)
end)
