local keymap = require('spm.core.keymap')

describe('keymap', function()
  describe('KeymapSpec:validate', function()
    it('should return true for a valid keymap', function()
      local valid_keymap = {
        map = '<leader>t',
        cmd = function() print('test') end,
      }
      setmetatable(valid_keymap, keymap.KeymapSpec)
      local valid, err = valid_keymap:validate()
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it('should return an error if the keymap is not a table', function()
      local invalid_keymap = 'not a table'
      setmetatable(
        { validate = keymap.KeymapSpec.validate },
        { __index = function() return invalid_keymap end }
      )
      ---@diagnostic disable-next-line: param-type-mismatch
      local valid, err = keymap.KeymapSpec.validate(invalid_keymap)
      assert.is_false(valid)
      assert.are.same('Keymap must be a table', err)
    end)

    it('should return an error if map is not a string', function()
      local invalid_keymap = {
        cmd = function() print('test') end,
      }
      setmetatable(invalid_keymap, keymap.KeymapSpec)
      local valid, err = invalid_keymap:validate()
      assert.is_false(valid)
      assert.are.same("Keymap must have a 'map' field of type string", err)
    end)

    it('should return an error if cmd is not a string or function', function()
      local invalid_keymap = {
        map = '<leader>t',
      }
      setmetatable(invalid_keymap, keymap.KeymapSpec)
      local valid, err = invalid_keymap:validate()
      assert.is_false(valid)
      assert.are.same("Keymap must have a 'cmd' field of type string or function", err)
    end)
  end)

  describe('map', function()
    it('should set a single keymap', function()
      local keymap_spec = {
        map = '<leader>t',
        cmd = function() print('test') end,
      }
      local success_count, total_count = keymap.map(keymap_spec)
      assert.are.same(1, success_count)
      assert.are.same(1, total_count)
    end)

    it('should set multiple keymaps', function()
      local keymap_specs = {
        {
          map = '<leader>t1',
          cmd = function() print('test1') end,
        },
        {
          map = '<leader>t2',
          cmd = function() print('test2') end,
        },
      }
      local success_count, total_count = keymap.map(keymap_specs)
      assert.are.same(2, success_count)
      assert.are.same(2, total_count)
    end)

    it('should handle filetype-specific keymaps', function()
      local keymap_spec = {
        map = '<leader>t',
        cmd = function() print('test') end,
        ft = 'lua',
      }
      local success_count, total_count = keymap.map(keymap_spec)
      assert.are.same(1, success_count)
      assert.are.same(1, total_count)
    end)

    it('should return the number of successfully set keymaps', function()
      local keymap_specs = {
        {
          map = '<leader>t1',
          cmd = function() print('test1') end,
        },
        {
          map = '<leader>t2',
        },
      }
      local success_count, total_count = keymap.map(keymap_specs)
      assert.are.same(1, success_count)
      assert.are.same(2, total_count)
    end)
  end)
end)
