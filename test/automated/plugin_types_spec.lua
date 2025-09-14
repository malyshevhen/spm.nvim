local PluginConfig = require('spm.core.plugin_types').PluginConfig
local PluginSpec = require('spm.core.plugin_types').PluginSpec

describe('plugin_types', function()
  describe('PluginSpec:valid', function()
    it('should return true for a valid plugin', function()
      local valid_plugin = {
        src = 'https://github.com/test/test',
      }
      setmetatable(valid_plugin, PluginSpec)
      local ok, err = valid_plugin:valid()
      assert.is_true(ok)
    end)

    it('should return an error if the plugin is not a table', function()
      local invalid_plugin = 'not a table'
      setmetatable(
        { validate = PluginSpec.valid },
        { __index = function() return invalid_plugin end }
      )
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok, err = PluginSpec.valid(invalid_plugin)
      assert.is_false(ok)
      assert.is_string(err)
    end)

    it('should return an error if src is not a valid https url', function()
      local invalid_plugin = {
        src = 'http://github.com/test/test',
      }
      setmetatable(invalid_plugin, PluginSpec)
      local ok, err = invalid_plugin:valid()
      assert.is_false(ok)
      assert.is_string(err)
    end)
  end)

  describe('PluginConfig:valid', function()
    it('should return true for a valid config', function()
      local valid_config = {
        plugins = {
          {
            src = 'https://github.com/test/test',
          },
        },
      }
      ---@type spm.PluginConfig?, string?
      local config, err = PluginConfig.create(valid_config)
      assert.is_nil(err)
      local ok, err = config:valid()
      assert.is_true(ok)
    end)

    it('should return an error if the config is not a table', function()
      local invalid_config = 'not a table'
      setmetatable(
        { valid = PluginConfig.valid },
        { __index = function() return invalid_config end }
      )
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok, err = PluginConfig.valid(invalid_config)
      assert.is_false(ok)
      assert.is_string(err)
    end)

    it('should return an error if plugins is not an array', function()
      local invalid_config = {
        plugins = 'not an array',
      }
      setmetatable(invalid_config, PluginConfig)
      local ok, err = invalid_config:valid()
      assert.is_false(ok)
      assert.is_string(err)
    end)

    it('should return an error if any of the plugins are invalid', function()
      local invalid_config = {
        plugins = {
          {
            src = 'http://github.com/test/test',
          },
        },
      }
      setmetatable(invalid_config, PluginConfig)
      local ok, err = invalid_config:valid()
      assert.is_false(ok)
      assert.is_string(err)
    end)
  end)

  describe('PluginConfig:flatten_plugins', function()
    it('should flatten the plugins and their dependencies', function()
      local config = {
        plugins = {
          {
            src = 'https://github.com/test/test1',
            dependencies = {
              'https://github.com/test/test2',
            },
          },
          {
            src = 'https://github.com/test/test3',
          },
        },
      }
      setmetatable(config, PluginConfig)
      local flattened = config:flatten_plugins()
      assert.are.same(3, #flattened)
    end)
  end)
end)
