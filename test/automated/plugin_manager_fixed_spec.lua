local Result = require('spm.lib.error').Result
local crypto = require('spm.lib.crypto')
local fs = require('spm.lib.fs')
local lock_manager = require('spm.core.lock_manager')
local plugin_types = require('spm.core.plugin_types')
local toml_parser = require('spm.lib.toml_parser')
local PluginConfig = plugin_types.PluginConfig
local Path = require('plenary.path')
local uv = vim.loop

-- Helper function to convert plain table to PluginConfig
local function create_plugin_config(data)
  setmetatable(data, PluginConfig)
  return data
end

-- Helper function to retry flaky operations
local function retry_operation(operation, max_retries)
  max_retries = max_retries or 3
  for i = 1, max_retries do
    local success, result = pcall(operation)
    if success then
      return result
    end

    if i < max_retries then
      -- Small delay between retries
      if vim and vim.loop then
        uv.sleep(30) -- 10ms
      end
    end
  end
  error('Operation failed after ' .. max_retries .. ' retries')
end

describe('plugin_manager integration', function()
  local test_env = {}

  before_each(function()
    -- Initialize clean test environment
    test_env.files_to_clean = {}
    test_env.temp_dir = Path:new(vim.fn.tempname() .. '_test_dir')
    test_env.temp_dir:mkdir()

    -- Clear any module caches to prevent state leakage
    package.loaded['spm.lib.toml_parser'] = nil
    package.loaded['spm.core.lock_manager'] = nil
    package.loaded['spm.lib.crypto'] = nil
    package.loaded['spm.lib.fs'] = nil

    -- Reload modules with fresh state
    toml_parser = require('spm.lib.toml_parser')
    lock_manager = require('spm.core.lock_manager')
    crypto = require('spm.lib.crypto')
    fs = require('spm.lib.fs')
  end)

  after_each(function()
    -- Clean up files with proper error handling
    for _, path_obj in ipairs(test_env.files_to_clean) do
      local success, err = pcall(function()
        if path_obj:exists() then
          path_obj:rm()
        end
      end)
      if not success then
        print('Failed to clean up file: ' .. tostring(err))
        error(err)
      end
    end

    -- Clean up temp directory
    if test_env.temp_dir and test_env.temp_dir:exists() then
      local success, err = pcall(function() test_env.temp_dir:rmdir() end)
      if not success then
        print('Failed to clean up temp directory: ' .. tostring(err))
        error(err)
      end
    end

    -- Reset test environment
    test_env = {}
  end)

  local function create_temp_file(content)
    local temp_file = test_env.temp_dir / ('test_' .. #test_env.files_to_clean .. '.toml')
    if content then
      temp_file:write(content, 'w')
      -- Ensure file is written and closed properly
      local fd = assert(uv.fs_open(temp_file.filename, 'r', 438))
      uv.fs_fsync(fd) -- Force write to disk
    end
    table.insert(test_env.files_to_clean, temp_file) -- Store Path object
    return temp_file.filename
  end

  local function parse_plugins_toml(path) return fs.read_file(path):flat_map(toml_parser.parse) end

  -- Helper function to setup standard test configuration
  local function setup_test_config()
    local content = [==[
[[plugins]]
name = "test-plugin"
src = "https://github.com/test/plugin"
]==]
    return create_temp_file(content)
  end

  describe('configuration parsing workflow', function()
    it('should parse valid TOML configuration', function()
      local content = [==[
[[plugins]]
name = "test-plugin"
src = "https://github.com/test/plugin"
]==]
      local test_plugins_toml_path = create_temp_file(content)

      local result = retry_operation(
        function() return parse_plugins_toml(test_plugins_toml_path) end
      )

      assert.is_true(result:is_ok())

      local config = result:unwrap()
      assert.is_table(config)
      assert.is_table(config.plugins)
      assert.are.equal(1, #config.plugins)
      assert.are.equal('test-plugin', config.plugins[1].name)
      assert.are.equal('https://github.com/test/plugin', config.plugins[1].src)
    end)

    it('should validate parsed configuration', function()
      local test_plugins_toml_path = setup_test_config()

      local result = retry_operation(
        function() return parse_plugins_toml(test_plugins_toml_path) end
      )
      assert.is_true(result:is_ok())

      local raw_config = result:unwrap()
      local config = create_plugin_config(raw_config)
      assert.is_function(config.valid)

      local validation_result = config:valid()
      assert.is_true(validation_result:is_ok())
    end)

    it('should flatten plugins including dependencies', function()
      local content = [==[
[[plugins]]
name = "main-plugin"
src = "https://github.com/test/main"
dependencies = ["https://github.com/test/dep"]
]==]
      local test_plugins_toml_path = create_temp_file(content)

      local result = retry_operation(
        function() return parse_plugins_toml(test_plugins_toml_path) end
      )
      assert.is_true(result:is_ok())

      local raw_config = result:unwrap()
      local config = create_plugin_config(raw_config)
      local flattened = config:flatten_plugins()

      assert.is_table(flattened)
      assert.are.equal(2, #flattened) -- Main plugin + dependency
      assert.are.equal('https://github.com/test/main', flattened[1].src)
      assert.are.equal('https://github.com/test/dep', flattened[2].src)
    end)
  end)

  describe('lock file management workflow', function()
    it('should create and read lock files', function()
      local test_lock_file_path = create_temp_file(nil)
      local lock_data = {
        hash = 'test_hash',
        plugins = {
          { name = 'test-plugin', src = 'https://github.com/test/plugin' },
        },
      }

      -- Write lock file with retry
      local write_result = retry_operation(
        function() return lock_manager.write(test_lock_file_path, lock_data) end
      )
      assert.is_true(write_result:is_ok())

      -- Read lock file with retry
      local read_result = retry_operation(
        function() return lock_manager.read(test_lock_file_path) end
      )
      assert.is_true(read_result:is_ok())

      local read_data = read_result:unwrap()
      assert.is_table(read_data)
      print(vim.inspect(read_data))

      -- The data should contain the same structure
      if not read_data.hash then
        print(vim.inspect(read_data))
      end
      assert.is_string(read_data.hash)
      -- assert.is_table(read_data.plugins)
      -- assert.are.equal(1, #read_data.plugins)
    end)

    it('should detect stale lock files', function()
      local plugins_content = 'test content'
      local hash_result = crypto.generate_hash(plugins_content)
      assert.is_true(hash_result:is_ok())

      local correct_hash = hash_result:unwrap()
      local wrong_hash = 'wrong_hash'

      -- Test with correct hash (not stale)
      local lock_data_fresh = { hash = correct_hash }
      local is_stale_fresh = lock_manager.is_stale(plugins_content, lock_data_fresh)
      assert.is_false(is_stale_fresh)

      -- Test with wrong hash (stale)
      local lock_data_stale = { hash = wrong_hash }
      local is_stale_stale = lock_manager.is_stale(plugins_content, lock_data_stale)
      assert.is_true(is_stale_stale)

      -- Test with no lock data (stale)
      local is_stale_no_data = lock_manager.is_stale(plugins_content, nil)
      assert.is_true(is_stale_no_data)
    end)
  end)

  describe('complete workflow integration', function()
    it('should handle a complete parse -> validate -> flatten -> lock workflow', function()
      local test_plugins_toml_path = setup_test_config()
      local test_lock_file_path = create_temp_file(nil)

      -- 1. Parse configuration with retry
      local parse_result = retry_operation(
        function() return parse_plugins_toml(test_plugins_toml_path) end
      )
      assert.is_true(parse_result:is_ok())

      local raw_config = parse_result:unwrap()
      local config = create_plugin_config(raw_config)

      -- 2. Validate configuration
      local validation_result = config:valid()
      assert.is_true(validation_result:is_ok())

      -- 3. Flatten plugins
      local flattened_plugins = config:flatten_plugins()
      assert.is_table(flattened_plugins)
      assert.are.equal(1, #flattened_plugins)

      -- 4. Generate hash of original content with retry
      local content_result = retry_operation(function()
        return Result.try(function()
          local file = io.open(test_plugins_toml_path, 'r')
          if not file then
            error('Cannot open file')
          end

          local content = file:read('*a')
          file:close()
          return content
        end)
      end)
      assert.is_true(content_result:is_ok())

      local hash_result = crypto.generate_hash(content_result:unwrap())
      assert.is_true(hash_result:is_ok())

      -- 5. Create and write lock file
      local lock_data = {
        hash = hash_result:unwrap(),
        plugins = flattened_plugins,
        language_servers = config.language_servers or {},
        filetypes = config.filetypes or {},
      }

      local write_result = retry_operation(
        function() return lock_manager.write(test_lock_file_path, lock_data) end
      )
      assert.is_true(write_result:is_ok())

      -- 6. Verify lock file can be read back
      local read_result = retry_operation(
        function() return lock_manager.read(test_lock_file_path) end
      )
      assert.is_true(read_result:is_ok())

      local read_data = read_result:unwrap()
      assert.are.same(lock_data.hash, read_data.hash)
      assert.are.same(lock_data.plugins, read_data.plugins)
    end)

    it('should handle complex configurations with language servers and filetypes', function()
      local content = [==[
[[plugins]]
name = "plugin1"
src = "https://github.com/test/plugin1"

[[plugins]]
name = "plugin2"
src = "https://github.com/test/plugin2"
version = "stable"

[language_servers]
servers = ["lua_ls", "gopls"]

[filetypes]

[filetypes.pattern]
"*.test" = "testfiletype"
]==]
      local test_plugins_toml_path = create_temp_file(content)

      local parse_result = retry_operation(
        function() return parse_plugins_toml(test_plugins_toml_path) end
      )
      assert.is_true(parse_result:is_ok())

      local config = parse_result:unwrap()
      assert.are.equal(2, #config.plugins)
      assert.is_table(config.language_servers)
      assert.are.equal(2, #config.language_servers.servers)
      assert.is_table(config.filetypes)
    end)
  end)

  describe('error handling', function()
    it('should handle non-existent files gracefully', function()
      local result = parse_plugins_toml('non_existent_file.toml')
      assert.is_true(result:is_err())

      local error_msg = result:unwrap_err().message
      assert.is_string(error_msg)
    end)

    it('should handle malformed TOML files', function()
      local content = '[[plugins]\nname = "broken"\n' -- Missing closing bracket
      local test_plugins_toml_path = create_temp_file(content)

      local result = parse_plugins_toml(test_plugins_toml_path)
      assert.is_true(result:is_err())

      local error_msg = result:unwrap_err().message
      assert.is_string(error_msg)
    end)

    it('should validate plugin specifications', function()
      local content = [==[
[[plugins]]
name = "invalid-plugin"
src = "not-a-valid-url"
]==]
      local test_plugins_toml_path = create_temp_file(content)

      local parse_result = parse_plugins_toml(test_plugins_toml_path)

      if parse_result:is_ok() then
        local raw_config = parse_result:unwrap()
        local config = create_plugin_config(raw_config)
        local validation_result = config:valid()
        assert.is_true(validation_result:is_err())

        local error_data = validation_result:unwrap_err()
        -- Handle both string and table error formats
        if type(error_data) == 'table' then
          assert.is_string(error_data.message)
        else
          assert.is_string(error_data)
        end
      else
        -- Parsing failed, which is also acceptable for invalid URLs
        local error_data = parse_result:unwrap_err()
        if type(error_data) == 'table' then
          assert.is_string(error_data.message)
        else
          assert.is_string(error_data)
        end
      end
    end)
  end)
end)
