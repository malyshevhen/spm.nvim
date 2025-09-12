# Project Overview

`spm.nvim` is a plugin manager for Neovim. It is written in Lua and allows users to manage their plugins using a `plugins.toml` file.

## Directory Structure

*   `lua/spm/`: The root of the plugin's Lua code.
    *   `core/`: The core logic of the plugin manager.
    *   `lib/`: Utility modules for tasks like error handling, logging, and TOML parsing.
    *   `vendor/`: Third-party dependencies.
*   `test/`: Automated tests for the project.
    *   `automated/`: Busted specs for the core modules.
    *   `fixtures/`: TOML files used for testing.
*   `plugin/`: The entry point for the plugin.
*   `scripts/`: Helper scripts.

## Key Modules

The core logic of `spm.nvim` is located in the `lua/spm/core/` directory. Here's a breakdown of the key modules:

*   `config.lua`: Handles the user's configuration, merging it with default values.
*   `plugin_manager.lua`: The main orchestrator that reads the `plugins.toml` file, resolves dependencies, and manages the installation process.
*   `plugin_installer.lua`: Responsible for installing plugins using `vim.pack.add`.
*   `lock_manager.lua`: Manages the `spm.lock` file, which keeps track of the installed plugins and their versions.
*   `plugin_types.lua`: Defines the data structures used throughout the plugin, such as `PluginSpec` and `PluginConfig`.
*   `keymap.lua`: A utility module for setting up keymaps.

## Configuration

The plugins to be installed are defined in a `plugins.toml` file. The structure of this file is defined by the JSON schema in `plugins-schema.json`.

## Building and Running

### Testing

To run the automated tests, use the following command:

```bash
make test
```

This will run the `busted` tests located in the `test/automated/` directory.

#### Testing Guidelines

*   **Test Framework:** The project uses `busted` as the test framework and `plenary.nvim` for test utilities and mocking.
*   **Test File Convention:** Test files should be placed in the `test/automated/` directory and named with a `_spec.lua` suffix (e.g., `my_module_spec.lua`).
*   **Fixtures:** Test data, such as sample `plugins.toml` files, are located in the `test/fixtures/` directory.
*   **Coverage:** All new modules and significant changes to existing modules should be accompanied by corresponding tests to maintain code quality and prevent regressions.

## Development Conventions

*   **Formatting:** The project uses `stylua` for code formatting. The configuration can be found in `.stylua.toml`.
*   **Linting:** The project uses `luacheck` for linting, configured via `.luarc.json`.
*   **Testing:** The project uses `busted` for testing.
*   **Dependencies:** Third-party dependencies are located in the `lua/spm/vendor/` directory. The project uses a vendored version of `toml.lua` for TOML parsing.