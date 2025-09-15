local Config = require('spm.core.config')

describe('Config #skip', function() -- TODO: fix CI file location
  it('should create a default configuration if no user config is provided', function()
    local config, err = Config:create()
    assert.is_nil(err)
    assert.is_table(config)
    local default_config = Config.default()
    assert.are.same(default_config, config)
  end)

  it('should merge user config with defaults', function()
    local user_config = {
      debug_mode = true,
    }
    local config, err = Config.create(user_config)
    assert.is_nil(err)
    assert.is_table(config)
    assert.is_true(config.debug_mode)
  end)

  it('should set the default plugins_toml_path if not provided', function()
    local config, err = Config:create()
    assert.is_nil(err)
    assert.is_table(config)
    assert.are.same(vim.fn.stdpath('config') .. '/plugins.toml', config.plugins_toml_path)
  end)

  it('should set the default lock_file_path if not provided', function()
    local config, err = Config:create()
    assert.is_nil(err)
    assert.is_table(config)
    assert.are.same(vim.fn.stdpath('data') .. '/spm.lock', config.lock_file_path)
  end)

  it('should return an error if the config is not a table', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local config, err = Config:create('not a table')
    assert.is_nil(config)
    assert.is_string(err)
  end)

  it('should return an error if plugins_toml_path is not a string or nil', function()
    local config, err = Config:create({ plugins_toml_path = 123 })
    assert.is_nil(config)
    assert.is_string(err)
  end)

  it('should return an error if lock_file_path is not a string or nil', function()
    local config, err = Config:create({ lock_file_path = 123 })
    assert.is_nil(config)
    assert.is_string(err)
  end)

  it('should return an error if auto_source_configs is not a boolean', function()
    local config, err = Config:create({ auto_source_configs = 'true' })
    assert.is_nil(config)
    assert.is_string(err)
  end)

  it('should return an error if auto_setup_keymaps is not a boolean', function()
    local config, err = Config:create({ auto_setup_keymaps = 'true' })
    assert.is_nil(config)
    assert.is_string(err)
  end)

  it('should return an error if show_startup_messages is not a boolean', function()
    local config, err = Config:create({ show_startup_messages = 'true' })
    assert.is_nil(config)
    assert.is_string(err)
  end)

  it('should return an error if debug_mode is not a boolean', function()
    local config, err = Config:create({ debug_mode = 'true' })
    assert.is_nil(config)
    assert.is_string(err)
  end)

  it('should return an error if plugins.toml does not exist', function()
    local config, err = Config:create({ plugins_toml_path = '/tmp/non_existent_plugins.toml' })
    assert.is_nil(config)
    assert.is_string(err)
  end)
end)
