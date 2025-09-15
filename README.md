# spm.nvim

A simple and efficient Neovim plugin manager written in Lua. SPM (Simple Plugin Manager) provides a declarative way to manage your Neovim plugins using TOML configuration files.

## Features

- **TOML Configuration**: Define plugins, language servers, and filetypes in a clean TOML format
- **Lock File System**: Ensures reproducible plugin installations with hash-based locking
- **Dependency Management**: Support for plugin dependencies
- **Version Pinning**: Pin plugins to specific branches, tags, or commits
- **Language Server Integration**: Configure LSP servers declaratively
- **Custom Filetypes**: Define custom filetype mappings
- **Built-in TOML Parser**: No external dependencies for configuration parsing
- **Comprehensive Testing**: Full test suite with Busted

## Prerequisites

- Neovim >= 0.12.0

## Installation

### Using vim.pack

```lua
vim.pack.add({
  src = 'https://github.com/malyshevhen/spm.nvim',
})

require('spm').setup()
```

### Manual Installation

Clone the repository and add to your Neovim runtime path:

```bash
git clone https://github.com/malyshevhen/spm.nvim ~/.local/share/nvim/site/pack/spm/start/spm.nvim
```

## Configuration

Create a `plugins.toml` file in your Neovim config directory:

```toml
[plugins]
  # Basic plugin
  { name = "alpha-nvim", src = "https://github.com/goolord/alpha-nvim" }

  # Plugin with version pinning
  { name = "neotest", src = "https://github.com/nvim-neotest/neotest", version = "v4.0.0" }

  # Plugin with dependencies
  {
    name = "neotest",
    src = "https://github.com/nvim-neotest/neotest",
    dependencies = [
      "https://github.com/nvim-lua/plenary.nvim"
    ]
  }

[language_servers]
  servers = ["lua_ls", "gopls", "tsserver"]

[filetypes]
  [filetypes.pattern]
    "*.raml" = "raml"
    "docker-compose*.yml" = "yaml.docker-compose"
```

## Usage

### Basic Setup

```lua
require('spm').setup({
  plugins_toml_path = vim.fn.stdpath('config') .. '/plugins.toml',
  lock_file_path = vim.fn.stdpath('config') .. '/plugins.lock',
  debug_mode = false,
  show_startup_messages = true,
})
```

### Configuration Options

- `plugins_toml_path`: Path to your plugins.toml configuration file
- `lock_file_path`: Path where the lock file will be stored
- `debug_mode`: Enable debug logging
- `show_startup_messages`: Show startup messages

### Keymap Integration

SPM provides a keymap compatibility system:

```lua
require('spm').keymaps({
  { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Find files' },
  { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Live grep' },
})
```

## Lock File System

SPM uses a lock file to ensure reproducible installations:

- Automatically generated when plugins are installed
- Contains plugin versions and configuration hash
- Prevents unnecessary reinstallations when configuration hasn't changed
- Can be manually updated with `force_reinstall = true`

## Testing

Run the test suite:

```bash
make test
```

Or run specific test types:

```bash
make unit-test      # Run unit tests
make automated-test # Run integration tests
```

## Development

### Code Style

- **Language**: Lua 5.4
- **Formatting**: 2 spaces, 100 columns, Unix line endings
- **Naming**: snake_case for functions/variables, PascalCase for modules
- **Types**: EmmyLua annotations required
- **Error handling**: Railway oriented programming pattern

### Testing Framework

Uses Busted for testing with custom Neovim integration.

### Linting

Code is formatted with Stylua. Run:

```bash
stylua lua/
```

## Roadmap

### Phase 1: Core Stability (v0.2.0)

- [ ] **Code Quality**
  - [x] Improve validation function structure
  - [ ] Clean up temporary lock file workarounds

- [ ] **Error Handling Improvements**
  - [ ] Enhanced plugin specification validation
  - [ ] Improved error messages and debugging

### Phase 2: Performance & Reliability (v0.3.0)

- [ ] **User Commands**
  - [ ] Add commands for plugin management (`:SPMList`, `:SPMUpdate`, etc.)
  - [ ] Implement debugging commands
  - [ ] Add status reporting functionality

- [ ] **Async Operations**
  - [ ] Move file system operations to async `vim.loop` flow
  - [ ] Implement proper SHA256 hashing function
  - [ ] Optimize plugin installation process

### Phase 3: User Experience (v0.4.0)

- [ ] **TOML Parser Fixes**
  - [ ] Better malformed TOML file handling
  - [ ] Fix multiline basic strings and leading newline trimming
  - [ ] Implement proper string escaping sequences
  - [ ] Add CRLF line ending support
  - [ ] Fix whitespace handling in table structures
  - [ ] Support quoted keys and special characters in keys
  - [ ] Handle nested table arrays correctly

- [ ] **Configuration Enhancements**
  - [ ] Conditional plugin loading
  - [ ] Better configuration validation feedback

### Phase 4: Advanced Features (v0.5.0)

- [ ] **Plugin Ecosystem**
  - [ ] Plugin dependency conflict resolution
  - [ ] Plugin health checks and cleanup
  - [ ] Support for plugin update channels

- [ ] **Integration Features**
  - [ ] Lazy loading of configuration files
  - [ ] Better LSP server management
  - [ ] Enhanced filetype detection
  - [ ] Simple UI for plugin management and configuration

## Known Issues

### TOML Parser Limitations

The built-in TOML parser has some known limitations that may affect certain TOML features:

- **Multiline strings**: Basic multiline strings with leading newline trimming not fully supported
- **String escaping**: Some escape sequences in strings may not be handled correctly
- **CRLF line endings**: Support for Windows-style line endings is incomplete
- **Complex table structures**: Some edge cases with nested tables and quoted keys
- **Special characters in keys**: Certain special characters in table keys may cause parsing issues

### Test Coverage Gaps

Several test cases are currently skipped due to implementation issues:

- **TOML parsing edge cases**: Tests for whitespace handling, quoted keys, and nested structures
- **Error handling**: Malformed TOML files and invalid plugin specifications
- **Integration tests**: Some integration tests need refactoring for better reliability

### Workarounds

- Use simple TOML structures when possible
- Avoid complex string escaping in configuration files
- Ensure consistent line endings (LF preferred)
- Test configurations thoroughly before deployment

## License

MIT
