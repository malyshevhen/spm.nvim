local pack_installer = require('spm.core.plugin_installer')

describe('pack_installer', function()
  local old_vim_pack

  before_each(function() old_vim_pack = vim.pack end)

  after_each(function() vim.pack = old_vim_pack end)

  it('should call vim.pack.add with the correct arguments', function()
    local called = false
    vim.pack = {
      add = function(specs, opts)
        called = true
        assert.are.same(1, #specs)
        assert.are.same('test/test', specs[1].name)
        assert.are.same(true, opts.load)
      end,
    }

    local plugins = {
      {
        name = 'test/test',
        src = 'https://github.com/test/test',
      },
    }

    local ok, err = pack_installer.install(plugins)
    assert.is_true(ok)
    assert.is_true(called)
  end)

  it('should return an error if vim.pack is not available', function()
    vim.pack = {}
    local ok, err = pack_installer.install({ { src = 'https://github.com/test/test' } })
    assert.is_nil(ok)
    assert.is_string(err)
  end)

  it('should do nothing if no plugins are provided', function()
    local called = false
    vim.pack = {
      add = function() called = true end,
    }

    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, err = pack_installer.install(nil)
    assert.is_true(ok)
    assert.is_false(called)
  end)
end)
