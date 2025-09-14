local Result = require('spm.lib.error').Result
local crypto = require('spm.lib.crypto')
local lock_manager = require('spm.core.lock_manager')
local plugin_types = require('spm.core.plugin_types')
local toml_parser = require('spm.lib.toml_parser')
local PluginConfig = plugin_types.PluginConfig
local Path = require('plenary.path')

-- Helper function to convert plain table to PluginConfig
local function create_plugin_config(data)
  setmetatable(data, PluginConfig)
  return data
end

describe('plugin_manager integration', function()
  local files_to_clean = {}

  local function create_temp_file(content)
    local temp_file = Path:new(vim.fn.tempname())
    if content then temp_file:write(content, 'w') end
    table.insert(files_to_clean, temp_file)
    return temp_file.filename
  end

  after_each(function()
    for _, file in ipairs(files_to_clean) do
      local success, err = pcall(function() file:rm() end)
      if not success then print('Failed to clean up file: ' .. tostring(err)) end
    end
    files_to_clean = {}
  end)

  describe('configuration parsing workflow', function()
    it('should parse valid TOML configuration', function()
      local content = [=[
[[plugins]]
name = "test-plugin"
src = "https://github.com/test/plugin"
]=]
      local test_plugins_toml_path = create_temp_file(content)

      local result = toml_parser.parse_plugins_toml(test_plugins_toml_path)
      assert.is_true(result:is_ok())

      local config = result:unwrap()
      assert.is_table(config)
      assert.is_table(config.plugins)
      assert.are.equal(1, #config.plugins)
      assert.are.equal('test-plugin', config.plugins[1].name)
      assert.are.equal('https://github.com/test/plugin', config.plugins[1].src)
    end)

    it('should validate parsed configuration', function()
      local content = [=[
[[plugins]]
name = "test-plugin"
src = "https://github.com/test/plugin"
]=]
      local test_plugins_toml_path = create_temp_file(content)

      local result = toml_parser.parse_plugins_toml(test_plugins_toml_path)
      assert.is_true(result:is_ok())

      local raw_config = result:unwrap()
      local config = create_plugin_config(raw_config)
      assert.is_function(config.validate)
      local validation_result = config:validate()
      assert.is_true(validation_result:is_ok())
    end)

    it('should flatten plugins including dependencies', function()
      local content = [=[
[[plugins]]
name = "main-plugin"
src = "https://github.com/test/main"
dependencies = ["https://github.com/test/dep"]
]=]
      local test_plugins_toml_path = create_temp_file(content)

      local result = toml_parser.parse_plugins_toml(test_plugins_toml_path)
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

      -- Write lock file
      local write_result = lock_manager.write(test_lock_file_path, lock_data)
      assert.is_true(write_result:is_ok())

      -- Read lock file
      local read_result = lock_manager.read(test_lock_file_path)
      assert.is_true(read_result:is_ok())

      local read_data = read_result:unwrap()
      assert.is_table(read_data)

      -- The data should contain the same structure
      assert.is_string(read_data.hash)
      assert.is_table(read_data.plugins)
      assert.are.equal(1, #read_data.plugins)
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
      local content = [=[
[[plugins]]
name = "test-plugin"
src = "https://github.com/test/plugin"
]=]
      local test_plugins_toml_path = create_temp_file(content)
      local test_lock_file_path = create_temp_file(nil)

      -- 1. Parse configuration
      local parse_result = toml_parser.parse_plugins_toml(test_plugins_toml_path)
      assert.is_true(parse_result:is_ok())

      local raw_config = parse_result:unwrap()
      local config = create_plugin_config(raw_config)

      -- 2. Validate configuration
      local validation_result = config:validate()
      assert.is_true(validation_result:is_ok())

      -- 3. Flatten plugins
      local flattened_plugins = config:flatten_plugins()
      assert.is_table(flattened_plugins)
      assert.are.equal(1, #flattened_plugins)

      -- 4. Generate hash of original content
      local content_result = Result.try(function()
        local file = io.open(test_plugins_toml_path, 'r')
        if not file then error('Cannot open file') end

        local content = file:read('*a')
        file:close()
        return content
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

      local write_result = lock_manager.write(test_lock_file_path, lock_data)
      assert.is_true(write_result:is_ok())

      -- 6. Verify lock file can be read back
      local read_result = lock_manager.read(test_lock_file_path)
      assert.is_true(read_result:is_ok())

      local read_data = read_result:unwrap()
      assert.are.same(lock_data.hash, read_data.hash)
      assert.are.same(lock_data.plugins, read_data.plugins)
    end)

    it('should handle complex configurations with language servers and filetypes', function()
      local content = [=[
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
]=]
      local test_plugins_toml_path = create_temp_file(content)

      local parse_result = toml_parser.parse_plugins_toml(test_plugins_toml_path)
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
      local result = toml_parser.parse_plugins_toml('non_existent_file.toml')
      assert.is_true(result:is_err())
    end)

    it('should handle malformed TOML files', function()
      local content = '[[plugins]\nname = "broken"\n'
      local test_plugins_toml_path = create_temp_file(content)

      local success, result = pcall(
        function() return toml_parser.parse_plugins_toml(test_plugins_toml_path) end
      )

      if success then
        assert.is_true(result:is_err())
      else
        -- Parsing error thrown directly, which is also acceptable behavior
        assert.is_true(true)
      end
    end)

    it('should validate plugin specifications', function()
      local content = [=[
[[plugins]]
name = "invalid-plugin"
src = "not-a-valid-url"
]=]
      local test_plugins_toml_path = create_temp_file(content)

      local success, parse_result = pcall(
        function() return toml_parser.parse_plugins_toml(test_plugins_toml_path) end
      )

      if success and parse_result and parse_result.is_ok then
        if parse_result:is_ok() then
          local raw_config = parse_result:unwrap()
          local config = create_plugin_config(raw_config)
          local validation_result = config:validate()
          assert.is_true(validation_result:is_err())
        end
      else
        -- Either parsing failed or threw an error, both are acceptable
        assert.is_true(true)
      end
    end)
  end)
end)
