local uv = vim.loop

local crypto, fs, lock_manager, plugin_types, toml, PluginConfig

-- Helper function to convert plain table to PluginConfig
local function create_plugin_config(data)
  setmetatable(data, PluginConfig)
  return data
end

-- Helper function to retry flaky operations
describe('plugin_manager integration', function()
  local test_env = {}

  before_each(function()
    -- Initialize clean test environment
    test_env.files_to_clean = {}
    test_env.temp_dir = vim.fn.tempname() .. '_test_dir'
    vim.uv.fs_mkdir(test_env.temp_dir, 448)

    -- Clear any module caches to prevent state leakage
    package.loaded['spm.lib.toml_parser'] = nil
    package.loaded['spm.core.lock_manager'] = nil
    package.loaded['spm.lib.crypto'] = nil
    package.loaded['spm.lib.fs'] = nil
    package.loaded['spm.lib.util'] = nil
    package.loaded['spm.lib.toml'] = nil
    package.loaded['spm.lib.toml'] = nil
    package.loaded['spm.lib.toml.encoder'] = nil
    package.loaded['spm.core.plugin_types'] = nil

    -- Reload modules with fresh state
    toml = require('spm.lib.toml')
    lock_manager = require('spm.core.lock_manager')
    crypto = require('spm.lib.crypto')
    fs = require('spm.lib.fs')
    plugin_types = require('spm.core.plugin_types')
    PluginConfig = plugin_types.PluginConfig
  end)

  after_each(function()
    -- Clean up files with proper error handling
    for _, file_path in ipairs(test_env.files_to_clean) do
      local success, err = pcall(function() os.remove(file_path) end)
      if not success then
        print('Failed to clean up file: ' .. tostring(err))
        error(err)
      end
    end

    -- Clean up temp directory
    if test_env.temp_dir then
      local success, err = pcall(function() vim.uv.fs_rmdir(test_env.temp_dir) end)
      if not success then
        print('Failed to clean up temp directory: ' .. tostring(err))
        error(err)
      end
    end

    -- Reset test environment
    test_env = {}
  end)

  local function create_temp_file(content)
    local temp_file_path = test_env.temp_dir .. '/test_' .. #test_env.files_to_clean .. '.toml'
    if content then
      local f = io.open(temp_file_path, 'w')
      if f then
        f:write(content)
        f:close()
        -- Ensure file is written and closed properly
        local fd = assert(uv.fs_open(temp_file_path, 'r', 438))
        uv.fs_fsync(fd) -- Force write to disk
      end
    end
    table.insert(test_env.files_to_clean, temp_file_path) -- Store file path
    return temp_file_path
  end

  local function parse_plugins_toml(path)
    local content, err = fs.read_file(path)
    if err then return nil, err end
    return toml.parse(content)
  end

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

      local config, err = parse_plugins_toml(test_plugins_toml_path)

      assert.is_nil(err)
      assert.is_table(config)
      assert.is_table(config.plugins)
      assert.are.equal(1, #config.plugins)
      assert.are.equal('test-plugin', config.plugins[1].name)
      assert.are.equal('https://github.com/test/plugin', config.plugins[1].src)
    end)

    it('should validate parsed configuration', function()
      local test_plugins_toml_path = setup_test_config()

      local raw_config, err = parse_plugins_toml(test_plugins_toml_path)
      assert.is_nil(err)

      local config = create_plugin_config(raw_config)
      assert.is_function(config.valid)

      local ok, valid_err = config:valid()
      assert.is_true(ok)
    end)

    it('should flatten plugins including dependencies', function()
      local content = [==[
[[plugins]]
name = "main-plugin"
src = "https://github.com/test/main"
dependencies = ["https://github.com/test/dep"]
]==]
      local test_plugins_toml_path = create_temp_file(content)

      local raw_config, err = parse_plugins_toml(test_plugins_toml_path)
      assert.is_nil(err)

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
      local ok, write_err = lock_manager.write(test_lock_file_path, lock_data)
      assert.is_true(ok)

      -- Read lock file with retry
      local read_data, read_err = lock_manager.read(test_lock_file_path)
      assert.is_nil(read_err)
      assert.is_table(read_data)

      -- The data should contain the same structure
      ---@diagnostic disable-next-line: empty-block
      if not read_data.hash then
        -- TODO: Remove this once the lock file is fixed
      end
      assert.is_string(read_data.hash)
      assert.is_table(read_data.plugins)
      assert.are.equal(1, #read_data.plugins)
    end)

    it('should detect stale lock files', function()
      local plugins_content = 'test content'
      local correct_hash, err = crypto.generate_hash(plugins_content)
      assert.is_nil(err)

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
      local raw_config, err = parse_plugins_toml(test_plugins_toml_path)
      assert.is_nil(err)
      assert.is_table(raw_config)

      local config = create_plugin_config(raw_config)

      -- 2. Validate configuration
      local ok, valid_err = config:valid()
      assert.is_true(ok)

      -- 3. Flatten plugins
      local flattened_plugins = config:flatten_plugins()
      assert.is_table(flattened_plugins)
      assert.are.equal(1, #flattened_plugins)

      -- 4. Generate hash of original content with retry
      local content, content_err = fs.read_file(test_plugins_toml_path)
      assert.is_nil(content_err)
      assert.is_string(content)

      local hash, hash_err = crypto.generate_hash(content)
      assert.is_nil(hash_err)

      -- 5. Create and write lock file
      local lock_data = {
        hash = hash,
        plugins = flattened_plugins,
        language_servers = config.language_servers or {},
        filetypes = config.filetypes or {},
      }

      local ok, write_err = lock_manager.write(test_lock_file_path, lock_data)
      assert.is_true(ok)

      -- 6. Verify lock file can be read back
      local read_data, read_err = lock_manager.read(test_lock_file_path)
      assert.is_nil(read_err)
      assert.is_table(read_data)
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

      local config, err = parse_plugins_toml(test_plugins_toml_path)
      assert.is_nil(err)
      assert.is_table(config)
      assert.are.equal(2, #config.plugins)
      assert.is_table(config.language_servers)
      assert.are.equal(2, #config.language_servers.servers)
      assert.is_table(config.filetypes)
    end)
  end)

  describe('error handling', function()
    it('should handle non-existent files gracefully', function()
      local config, err = parse_plugins_toml('non_existent_file.toml')
      assert.is_nil(config)
      assert.is_string(err)
    end)

    it('should handle malformed TOML files #skip', function() -- TODO: fix this
      local content = '[[plugins]\nname = "broken"\n' -- Missing closing bracket
      local test_plugins_toml_path = create_temp_file(content)

      local config, err = parse_plugins_toml(test_plugins_toml_path)
      assert.is_nil(config)
      assert.is_string(err)
    end)

    it('should validate plugin specifications #skip', function() -- TODO: fix this
      local content = [==[
[[plugins]]
name = "invalid-plugin"
src = "not-a-valid-url"
]==]
      local test_plugins_toml_path = create_temp_file(content)

      local raw_config, parse_err = parse_plugins_toml(test_plugins_toml_path)

      if raw_config then
        local config = create_plugin_config(raw_config)
        local ok, valid_err = config:valid()
        assert.is_false(ok)
        assert.is_string(valid_err)
      else
        -- Parsing failed, which is also acceptable for invalid URLs
        assert.is_string(parse_err)
      end
    end)
  end)
end)
