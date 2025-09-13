local TOML = {
  -- denotes the current supported TOML version
  version = 0.40,

  -- sets whether the parser should follow the TOML spec strictly
  -- currently, no errors are thrown for the following rules if strictness is turned off:
  --   tables having mixed keys
  --   redefining a table
  --   redefining a key within a table
  strict = true,
}

-- converts TOML data into a lua table
TOML.parse = require('spm.vendor.toml.parse')

-- converts a lua table into TOML data
TOML.encode = require('spm.lib.encoder').encode

return TOML
