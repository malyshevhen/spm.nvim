local toml_parser = require('spm.toml_parser')

describe('toml_parser', function()
  it('should parse a valid toml file', function()
    local result = toml_parser.parse_file('test/fixtures/valid_toml.toml')
    assert.is_true(result:is_ok())
    local plugins = result:unwrap()
    assert.are.same({
      filetypes = {
        pattern = {
          ['docker-compose%.yml'] = 'yaml.docker-compose',
        },
      },
      language_servers = {
        servers = {
          'lua_ls',
        },
      },
      plugins = {
        {
          name = 'alpha-nvim',
          src = 'https://github.com/goolord/alpha-nvim',
        },
        {
          name = 'neotest',
          src = 'https://github.com/nvim-neotest/neotest',
          dependencies = {
            'https://github.com/nvim-lua/plenary.nvim',
          },
        },
      },
    }, plugins)
  end)

  it('should return an error if the file does not exist', function()
    local result = toml_parser.parse_file('test/fixtures/non_existent_file.toml')
    assert.is_true(result:is_err())
    assert.are.same('Cannot read file: test/fixtures/non_existent_file.toml', result.error.message)
  end)

  it('should return an error if the file is not a valid toml file', function()
    local result = toml_parser.parse_file('test/fixtures/invalid_toml.toml')
    assert.is_true(result:is_err())
    assert.truthy(result.error.message:find('Cannot parse file: test/fixtures/invalid_toml.toml'))
  end)

  it('should encode a lua table to a toml string', function()
    local tbl = {
      test = 'value',
    }
    local result = toml_parser.encode(tbl)
    assert.is_true(result:is_ok())
    assert.are.same('test = "value"', result:unwrap())
  end)

  it('should return an error if the input is not a table', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local result = toml_parser.encode('not a table')

    assert.is_true(result:is_err())
    assert.are.same('Input must be a table', result.error.message)
  end)

  it('should parse a valid plugins.toml file', function()
    local result = toml_parser.parse_plugins_toml('test/fixtures/valid_toml.toml')
    assert.is_true(result:is_ok())
    local config = result:unwrap()
    assert.are.same({
      filetypes = {
        pattern = {
          ['docker-compose%.yml'] = 'yaml.docker-compose',
        },
      },
      language_servers = {
        servers = {
          'lua_ls',
        },
      },
      plugins = {
        {
          name = 'alpha-nvim',
          src = 'https://github.com/goolord/alpha-nvim',
        },
        {
          name = 'neotest',
          src = 'https://github.com/nvim-neotest/neotest',
          dependencies = {
            'https://github.com/nvim-lua/plenary.nvim',
          },
        },
      },
    }, config)
  end)

  it('should return an error if the file does not exist', function()
    local result = toml_parser.parse_plugins_toml('test/fixtures/non_existent_file.toml')

    assert.is_true(result:is_err())
    assert.are.same('Cannot read file: test/fixtures/non_existent_file.toml', result.error.message)
  end)

  it('should return an error if the file does not contain a [[plugins]] section', function()
    local result = toml_parser.parse_plugins_toml('test/fixtures/no_plugins.toml')

    assert.is_true(result:is_err())
    assert.truthy(result.error.message:find('Cannot parse file: test/fixtures/no_plugins.toml'))
  end)

  it('should return a warning if the [[plugins]] section is empty', function()
    local result = toml_parser.parse_plugins_toml('test/fixtures/empty_plugins.toml')

    assert.is_true(result:is_ok())
  end)
end)
