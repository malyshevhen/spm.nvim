# Agent Instructions for spm.nvim

## Commands
- **Test all**: `make test`
- **Test single file**: `nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedFile test/automated/<file>_spec.lua { minimal_init = './scripts/minimal_init.vim' }"`
- **Format code**: `stylua lua/`
- **Type check**: Lua LSP (configured in .luarc.json)

## Code Style
- **Syntax**: Lua 5.4
- **Formatting**: 2 spaces, 100 columns, Unix line endings, single quotes, sorted requires
- **Naming**: snake_case for functions/variables, PascalCase for modules/classes
- **Types**: EmmyLua annotations required
- **Error handling**: Use Result type (Railway oriented programming)
- **Logging**: Use logger module for debug/info messages
- **Imports**: Group by stdlib, then third-party, then local modules