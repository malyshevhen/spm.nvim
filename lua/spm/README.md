# Simple Plugin Management System

A streamlined plugin management system for Neovim that replaces complex plugin managers with a TOML-based approach and immediate keymap setting.

## Overview

This system provides:

- **TOML-based plugin definition** - All plugins defined in `plugins.toml`
- **Immediate keymap setting** - No collecting, keymaps are set instantly when declared
- **Compatibility layer** - Existing `K:map` syntax continues to work
- **Automatic configuration sourcing** - Plugins and keybindings sourced automatically
- **Built-in validation** - Type-safe plugin and keymap definitions

## Directory Structure

```
lua/simple_pm/
├── README.md           # This file
├── init.lua            # Main module interface
├── plugin_types.lua    # Type definitions for plugins
├── toml_parser.lua     # TOML file parser
├── plugin_installer.lua # Plugin installation logic (includes K:map compatibility)
└── keymap.lua          # Simplified keymap system
```

## Core Components

### 1. Plugin Definition (`plugins.toml`)

Define all plugins and dependencies in a single TOML file:

```toml
[[plugins]]
name = "nvim-treesitter"
src = "https://github.com/nvim-treesitter/nvim-treesitter"

[[plugins]]
name = "telescope.nvim"
src = "https://github.com/nvim-telescope/telescope.nvim"
dependencies = [
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-telescope/telescope-fzf-native.nvim"
]
```

### 2. Immediate Keymap System

Keymaps are set immediately when declared, not collected and batched:

**New Direct API:**

```lua
local keymap = require('simple_pm.keymap')
keymap.map({
  { map = '<leader>ff', cmd = '<cmd>Telescope find_files<CR>', desc = 'Find files' },
  { map = '<leader>w', cmd = '<cmd>w<CR>', desc = 'Save file' },
})
```

**Compatible K:map API (existing code continues to work):**

```lua
K:map {
  { map = '<leader>ff', cmd = '<cmd>Telescope find_files<CR>', desc = 'Find files' },
  { map = '<leader>w', cmd = '<cmd>w<CR>', desc = 'Save file' },
}
```

### 3. Automatic Configuration Sourcing

After plugin installation, files are automatically sourced in order:

1. `plugins.lua` or `plugins/*.lua` files
2. `keybindings.lua` or `keybindings/*.lua` files

## Usage

### Basic Setup

Replace your `init.lua` with:

```lua
-- Load basic options first
require('options')

-- Initialize simple plugin management
local simple_pm = require('simple_pm')
simple_pm.setup() -- Uses plugins.toml in config root

-- Load additional configuration
require('auto_cmds')
require('lsp_cfg')
```

### Advanced Setup

```lua
local simple_pm = require('simple_pm')
simple_pm.init({
  plugins_toml_path = vim.fn.stdpath('config') .. '/plugins.toml',
  auto_source_configs = true,
  auto_setup_keymaps = true,
  debug_mode = false,
})
```

### Debug Mode

```lua
local simple_pm = require('simple_pm')
simple_pm.setup_debug() -- Enables detailed logging
```

## Configuration Files

### Plugin Configuration

**Option 1: Single file** (`plugins.lua`):

```lua
-- Configure rose-pine theme
require('rose-pine').setup({
  variant = 'moon',
})
vim.cmd('colorscheme rose-pine')

-- Configure treesitter
require('nvim-treesitter.configs').setup({
  ensure_installed = { 'lua', 'python', 'javascript' },
  highlight = { enable = true },
})
```

**Option 2: Directory** (`plugins/theme.lua`, `plugins/editor.lua`, etc.):

```lua
-- plugins/theme.lua
require('rose-pine').setup({
  variant = 'moon',
})
vim.cmd('colorscheme rose-pine')
```

### Keybinding Configuration

**Option 1: Single file** (`keybindings.lua`):

```lua
-- Set leader key
vim.g.mapleader = ' '

-- File operations using K:map (compatibility)
K:map {
  { map = '<leader>w', cmd = '<cmd>w<CR>', desc = 'Save file' },
  { map = '<leader>q', cmd = '<cmd>q<CR>', desc = 'Quit' },
}
```

**Option 2: Directory** (`keybindings/editor.lua`, `keybindings/git.lua`, etc.):

```lua
-- keybindings/editor.lua
K:map {
  { map = '<leader>w', cmd = '<cmd>w<CR>', desc = 'Save file' },
  { map = '<C-h>', cmd = '<C-w>h', desc = 'Go to left window' },
}
```

## Keymap Features

### Keymap Specification

```lua
---@class KeymapSpec
---@field map string The key combination
---@field cmd string|function The command to execute
---@field desc string? Description for the keymap
---@field mode string|string[]? Mode(s) (default: 'n')
---@field ft string? Filetype restriction
---@field opts table? Additional vim.keymap.set options
```

### Examples

**Basic keymap:**

```lua
{ map = '<leader>w', cmd = '<cmd>w<CR>', desc = 'Save file' }
```

**Function command:**

```lua
{ map = '<leader>f', cmd = function() print('Hello!') end, desc = 'Say hello' }
```

**Multiple modes:**

```lua
{ map = '<leader>y', cmd = '"+y', desc = 'Copy to clipboard', mode = { 'n', 'v' } }
```

**Filetype-specific:**

```lua
{ map = '<leader>r', cmd = '<cmd>GoRun<CR>', desc = 'Run Go file', ft = 'go' }
```

## Commands

- `:SimplePMDebugPlugins` - Show all parsed plugins
- `:SimplePMTestKeymaps` - Test keymap system
- `:SimplePMReinstall` - Reinstall plugins and source configs

## Migration from Complex Plugin Managers

1. **Extract plugin URLs** to `plugins.toml`
2. **Move plugin configurations** to `plugins.lua` or `plugins/` directory
3. **Move keybindings** to `keybindings.lua` or `keybindings/` directory
4. **Replace init.lua** with simple PM setup
5. **Test with debug mode** enabled

## API Reference

### simple_pm Module

```lua
local simple_pm = require('simple_pm')

-- Main initialization
simple_pm.init(config)        -- Full initialization with config
simple_pm.setup(toml_path)    -- Quick setup
simple_pm.setup_debug()       -- Setup with debugging

-- Access subsystems
simple_pm.keymap()            -- Get keymap module
simple_pm.installer()         -- Get plugin installer module
```

### Keymap Module

```lua
local keymap = require('simple_pm.keymap')

-- Direct keymap setting
keymap.map(keymaps)          -- Set keymaps immediately
```

## Advantages

- **Immediate feedback** - Keymaps work as soon as they're defined
- **No batching complexity** - Simple, direct keymap setting
- **Full compatibility** - Existing `K:map` code works unchanged (built into plugin_installer)
- **Type safety** - Built-in validation for plugins and keymaps
- **Standard tools** - Uses `vim.pack.add` and `vim.keymap.set`
- **Clear separation** - Plugin definition vs. configuration vs. keybindings
- **Minimal architecture** - Only essential components, no unnecessary abstractions

## Performance

- **Fast startup** - No complex dependency resolution or abstractions
- **Immediate keymaps** - Direct vim.keymap.set calls, no intermediate storage
- **Efficient parsing** - TOML parsed once at startup
- **Minimal memory** - No persistent stores or compatibility layers

## Troubleshooting

### Check Plugin Parsing

```vim
:SimplePMDebugPlugins
```

### Test Keymap System

```vim
:SimplePMTestKeymaps
```

### Enable Debug Mode

```lua
require('simple_pm').init({ debug_mode = true })
```

### Common Issues

1. **TOML syntax errors** - Check brackets and quotes in `plugins.toml`
2. **Missing files** - Optional config files are silently skipped
3. **Keymap conflicts** - Check for duplicate key mappings
4. **Plugin URLs** - Ensure all URLs are HTTPS

---

_This system prioritizes simplicity and directness: one `keymap.map()` function that validates and sets keymaps immediately using `vim.keymap.set`._
