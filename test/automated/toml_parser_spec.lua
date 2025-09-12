local toml_parser = require('spm.lib.toml_parser')

describe('toml_parser', function()
  it('should parse a valid toml file', function()
    local content = [==[
[[plugins]]
name = "alpha-nvim"
src  = "https://github.com/goolord/alpha-nvim"

[[plugins]]
name         = "neotest"
src          = "https://github.com/nvim-neotest/neotest"
dependencies = ["https://github.com/nvim-lua/plenary.nvim"]

[language_servers]
servers = ["lua_ls"]

[filetypes]
[filetypes.pattern]
'docker-compose%.yml' = 'yaml.docker-compose'
]==]

    local result = toml_parser.parse(content)
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

  it('should return an error if the file is not a valid toml file', function()
    local invalid_content = '[[plugins]\nname = "broken"\n' -- Missing closing bracket
    local result = toml_parser.parse(invalid_content)
    assert.is_true(result:is_err())
    assert.truthy(result.error.message:find('Cannot parse TOML'))
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
end)