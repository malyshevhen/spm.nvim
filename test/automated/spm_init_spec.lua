local Path = require('plenary.path')
local spm = require('spm')

describe('spm.init', function()
  local test_env = {}

  before_each(function()
    test_env.files_to_clean = {}
    test_env.temp_dir = Path:new(vim.fn.tempname() .. '_spm_test')
    test_env.temp_dir:mkdir()

    -- Clear module caches to prevent state leakage
    package.loaded['spm'] = nil
    package.loaded['spm.lib.logger'] = nil
    package.loaded['spm.core.config'] = nil
    package.loaded['spm.core.keymap'] = nil
    package.loaded['spm.core.plugin_manager'] = nil

    -- Reload spm
    spm = require('spm')
  end)

  after_each(function()
    -- Clean up files
    for _, path_obj in ipairs(test_env.files_to_clean) do
      if path_obj:exists() then
        path_obj:rm()
      end
    end

    -- Clean up temp directory
    if test_env.temp_dir and test_env.temp_dir:exists() then
      test_env.temp_dir:rmdir()
    end

    test_env = {}
  end)

  local function create_temp_file(content)
    local temp_file = test_env.temp_dir / ('test_' .. #test_env.files_to_clean .. '.toml')
    if content then
      temp_file:write(content, 'w')
    end
    table.insert(test_env.files_to_clean, temp_file)
    return temp_file.filename
  end

  describe('spm table structure', function()
    it('should have required modules', function()
      assert.is_table(spm.config_module)
      assert.is_table(spm.keymap)
      assert.is_table(spm.plugin_manager)
    end)

    it('should have setup function', function() assert.is_function(spm.setup) end)

    it('should have keymaps function', function() assert.is_function(spm.keymaps) end)
  end)

  describe('spm.setup', function()
    it('should initialize successfully with valid config and existing files', function()
      local plugins_content = [=[
[[plugins]]
name = "test-plugin"
src = "https://github.com/test/plugin"
]=]
      local plugins_path = create_temp_file(plugins_content)
      local lock_path = create_temp_file('')

      local config = {
        plugins_toml_path = plugins_path,
        lock_file_path = lock_path,
        debug_mode = false,
        show_startup_messages = false,
      }

      -- This should not error
      assert.no_error(function() spm.setup(config) end)
    end)

    it('should initialize with default config', function()
      -- Create default paths if they don't exist
      local default_plugins = vim.fn.stdpath('config') .. '/plugins.toml'
      local default_lock = vim.fn.stdpath('data') .. '/spm.lock'

      -- Ensure files exist for test
      local plugins_file = Path:new(default_plugins)
      if not plugins_file:exists() then
        plugins_file:write('', 'w')
        table.insert(test_env.files_to_clean, plugins_file)
      end

      local lock_file = Path:new(default_lock)
      if not lock_file:exists() then
        lock_file:write('', 'w')
        table.insert(test_env.files_to_clean, lock_file)
      end

      -- This should not error
      assert.no_error(function() spm.setup() end)
    end)

    it('should fail with invalid config', function()
      local config = {
        plugins_toml_path = 123, -- Invalid type
      }

      -- This should error because config.create will fail
      assert.has.errors(function() spm.setup(config) end)
    end)

    it('should fail if plugins.toml does not exist', function()
      local config = {
        plugins_toml_path = '/non/existent/plugins.toml',
        lock_file_path = create_temp_file(''),
      }

      -- This should error because validate_files_exists will fail
      assert.has.errors(function() spm.setup(config) end)
    end)
  end)

  describe('spm.keymaps', function()
    it('should call keymap.map with provided keymaps', function()
      local keymaps = {
        { mode = 'n', lhs = '<leader>p', rhs = ':echo "test"<CR>' },
      }

      -- Mock keymap.map to verify it's called
      local original_map = spm.keymap.map
      local called_with = nil
      spm.keymap.map = function(kms) called_with = kms end

      spm.keymaps(keymaps)

      assert.are.same(keymaps, called_with)

      -- Restore
      spm.keymap.map = original_map
    end)

    it('should call keymap.map with empty table if no keymaps provided', function()
      local called_with = nil
      local original_map = spm.keymap.map
      spm.keymap.map = function(kms) called_with = kms end

      spm.keymaps()

      assert.are.same({}, called_with)

      spm.keymap.map = original_map
    end)
  end)

  describe('API protection', function()
    it('should prevent modification of the spm table', function()
      assert.has.errors(function() spm.new_field = 'test' end)
    end)

    it('should have protected metatable', function()
      local mt = getmetatable(spm)
      assert.is_table(mt)
      assert.are.equal('SimplePM API is protected', mt.__metatable)
    end)
  end)
end)
