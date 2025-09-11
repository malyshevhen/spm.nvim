---@diagnostic disable: undefined-field

local Config = require('spm.config')

describe('Config', function()
  it('should create a default configuration if no user config is provided', function()
    local result = Config.create()
    assert.is_true(result:is_ok())
    local config = result:unwrap()
    local default_config = Config.default()
    default_config.plugins_toml_path = default_config.config_root .. '/plugins.toml'
    assert.are.same(default_config, config)
  end)

  it('should merge user config with defaults', function()
    local user_config = {
      debug_mode = true,
    }
    local result = Config.create(user_config)
    assert.is_true(result:is_ok())
    local config = result:unwrap()
    assert.is_true(config.debug_mode)
  end)

  it('should set the default plugins_toml_path if not provided', function()
    local result = Config.create()
    assert.is_true(result:is_ok())
    local config = result:unwrap()
    assert.are.same(config.config_root .. '/plugins.toml', config.plugins_toml_path)
  end)

  it('should set the default lock_file_path if not provided', function()
    local result = Config.create()
    assert.is_true(result:is_ok())
    local config = result:unwrap()
    assert.are.same(vim.fn.stdpath('data') .. '/spm.lock', config.lock_file_path)
  end)

  it('should return an error if the config is not a table', function()
    local result = Config.create('not a table')
    assert.is_true(result:is_err())
  end)

  it('should return an error if plugins_toml_path is not a string or nil', function()
    local result = Config.create({ plugins_toml_path = 123 })
    assert.is_true(result:is_err())
    assert.are.same('plugins_toml_path must be a string or nil', result.error.message)
  end)

  it('should return an error if lock_file_path is not a string or nil', function()
    local result = Config.create({ lock_file_path = 123 })
    assert.is_true(result:is_err())
    assert.are.same('lock_file_path must be a string or nil', result.error.message)
  end)

  it('should return an error if auto_source_configs is not a boolean', function()
    local result = Config.create({ auto_source_configs = 'true' })
    assert.is_true(result:is_err())
    assert.are.same('auto_source_configs must be a boolean', result.error.message)
  end)

  it('should return an error if auto_setup_keymaps is not a boolean', function()
    local result = Config.create({ auto_setup_keymaps = 'true' })
    assert.is_true(result:is_err())
    assert.are.same('auto_setup_keymaps must be a boolean', result.error.message)
  end)

  it('should return an error if show_startup_messages is not a boolean', function()
    local result = Config.create({ show_startup_messages = 'true' })
    assert.is_true(result:is_err())
    assert.are.same('show_startup_messages must be a boolean', result.error.message)
  end)

  it('should return an error if debug_mode is not a boolean', function()
    local result = Config.create({ debug_mode = 'true' })
    assert.is_true(result:is_err())
    assert.are.same('debug_mode must be a boolean', result.error.message)
  end)

  it('should return an error if config_root is not a string', function()
    local result = Config.create({ config_root = 123 })
    assert.is_true(result:is_err())
    assert.are.same('config_root must be a string', result.error.message)
  end)

  it('should return an error if config_root is not a valid directory', function()
    local result = Config.create({ config_root = '/not/a/real/dir' })
    assert.is_true(result:is_err())
    assert.are.same('config_root must be a valid directory', result.error.message)
  end)

  it('should return an error if plugins.toml does not exist', function()
    local result = Config.create({ plugins_toml_path = '/tmp/non_existent_plugins.toml' })
    assert.is_true(result:is_ok())
    local config = result:unwrap()
    local file_result = config:validate_files_exists()
    assert.is_true(file_result:is_err())
    assert.are.same('plugins.toml not found at: /tmp/non_existent_plugins.toml', file_result.error.message)
  end)

  it('should return an error if config_root does not exist', function()
    local result = Config.create({ config_root = '/tmp/non_existent_dir' })
    assert.is_true(result:is_err())
    assert.are.same('config_root must be a valid directory', result.error.message)
  end)
end)
