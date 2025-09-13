---@module 'toml'
local toml = {}

---@type fun(data: string): table
toml.parse = require('spm.lib.toml.parser').parse

---@type fun(data: any): string?, string?
toml.encode = require('spm.lib.toml.encoder').encode

return toml
