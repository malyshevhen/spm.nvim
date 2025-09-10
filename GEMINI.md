# Project Overview

`spm.nvim` is a plugin manager for Neovim. It is written in Lua and allows users to manage their plugins using a `plugins.toml` file.

## Key Files

*   `lua/spm/plugin_manager.lua`: The core logic of the plugin manager. It handles parsing the configuration, installing plugins, and updating the lock file.
*   `plugins-schema.json`: A JSON schema that defines the structure of the `plugins.toml` file.
*   `Makefile`: Contains a `test` command for running the automated tests.
*   `README.md`: Provides general information about the project, including how to use it as a template.
*   `test/automated/`: Contains the automated tests for the project.

## Building and Running

### Testing

To run the tests, use the following command:

```bash
make test
```

This will run the automated tests using `busted`.

## Development Conventions

*   The project uses `stylua` for code formatting. The configuration can be found in `.stylua.toml`.
*   The project uses `luarc.json` to configure the Lua language server.
*   The project uses `busted` for testing.
*   The project uses a `plugins.toml` file to define the plugins to be installed. The schema for this file is defined in `plugins-schema.json`.
