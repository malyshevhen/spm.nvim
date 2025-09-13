local function encode(tbl)
  local toml = ''

  local cache = {}

  local function parse(tbl)
    for k, v in pairs(tbl) do
      if type(v) == 'boolean' then
        toml = toml .. k .. ' = ' .. tostring(v) .. '\n'
      elseif type(v) == 'number' then
        toml = toml .. k .. ' = ' .. tostring(v) .. '\n'
      elseif type(v) == 'string' then
        local quote = '"'
        v = v:gsub('\\', '\\\\')

        -- if the string has any line breaks, make it multiline
        if v:match('^\n(.*)$') then
          quote = quote:rep(3)
          v = '\\n' .. v
        elseif v:match('\n') then
          quote = quote:rep(3)
        end

        v = v:gsub('\b', '\\b')
        v = v:gsub('\t', '\\t')
        v = v:gsub('\f', '\\f')
        v = v:gsub('\r', '\r')
        v = v:gsub('"', '"')
        toml = toml .. k .. ' = ' .. quote .. v .. quote .. '\n'
      elseif type(v) == 'table' then
        local array, arrayTable = true, true
        local first = {}
        for kk, vv in pairs(v) do
          if type(kk) ~= 'number' then
            array = false
          end
          if type(vv) ~= 'table' then
            v[kk] = nil
            first[kk] = vv
            arrayTable = false
          end
        end

        if array then
          if arrayTable then
            -- double bracket syntax go!
            table.insert(cache, k)
            for _, vv in ipairs(v) do
              toml = toml .. '[[' .. table.concat(cache, '.') .. ']]\n'
              local current_plugin_props = {}
              for k3, v3 in pairs(vv) do
                if type(v3) ~= 'table' then
                  current_plugin_props[k3] = v3
                end
              end
              parse(current_plugin_props)
            end
            table.remove(cache)
          else
            -- plain ol boring array
            toml = toml .. k .. ' = [\n'
            for _, val in ipairs(first) do
              if type(val) == 'string' then
                local escaped_val = val:gsub('\\', '\\\\'):gsub('"', '\\"')
                toml = toml .. '  "' .. escaped_val .. '",\n'
              else
                toml = toml .. '  ' .. tostring(val) .. ',\n'
              end
            end
            toml = toml .. ']\n'
          end
        else
          -- just a key/value table, folks
          table.insert(cache, k)
          toml = toml .. '[' .. table.concat(cache, '.') .. ']\n'
          parse(first)
          parse(v)
          table.remove(cache)
        end
      end
    end
  end

  parse(tbl)

  return toml:sub(1, -2)
end

return encode
