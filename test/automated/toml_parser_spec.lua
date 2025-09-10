---@diagnostic disable: undefined-field

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
    assert.truthy(string.find(result.error.message, 'TOML parsing failed'))
  end)
end)
