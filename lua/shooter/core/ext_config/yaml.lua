-- ext_config yaml — schema-agnostic YAML parse/serialize.

local M = {}

--- Simple YAML parser (schema-agnostic, indent-tracking stack)
--- Handles nested keys, strings, numbers, booleans, comments.
---@param content string YAML content
---@return table Parsed table
function M.parse_yaml(content)
  local result = {}
  local stack = { { tbl = result, indent = -1 } }

  for line in content:gmatch('[^\n]+') do
    -- Skip comments and blank lines
    if line:match('^%s*#') or line:match('^%s*$') then
      goto continue
    end

    local indent = #(line:match('^(%s*)') or '')
    local key, value = line:match('^%s*([%w_][%w_%-]*):%s*(.*)')

    if not key then goto continue end

    -- Strip inline comments (space + # per YAML spec) and trailing whitespace
    value = value:gsub('%s+#.*$', ''):gsub('%s+$', '')

    -- Pop stack to find correct parent
    while #stack > 1 and stack[#stack].indent >= indent do
      table.remove(stack)
    end

    local parent = stack[#stack].tbl

    if value == '' then
      -- Nested object
      parent[key] = {}
      table.insert(stack, { tbl = parent[key], indent = indent })
    else
      -- Leaf value: parse type
      if value == 'true' then
        parent[key] = true
      elseif value == 'false' then
        parent[key] = false
      elseif tonumber(value) then
        parent[key] = tonumber(value)
      else
        local unquoted = value:match('^["\'](.+)["\']$')
        if unquoted then
          parent[key] = unquoted
        elseif value == '""' or value == "''" then
          parent[key] = ''
        else
          parent[key] = value
        end
      end
    end

    ::continue::
  end

  return result
end

--- Simple YAML serializer (nested tables to YAML string)
---@param tbl table Table to serialize
---@param indent_level number|nil Current indent level
---@return string YAML content
function M.serialize_yaml(tbl, indent_level)
  indent_level = indent_level or 0
  local lines = {}
  local prefix = string.rep('  ', indent_level)

  -- Sort keys alphabetically at every level
  local keys = {}
  for key in pairs(tbl) do keys[#keys + 1] = key end
  table.sort(keys)

  for _, key in ipairs(keys) do
    local value = tbl[key]
    if type(value) == 'table' then
      table.insert(lines, prefix .. key .. ':')
      table.insert(lines, M.serialize_yaml(value, indent_level + 1))
    elseif type(value) == 'string' then
      -- Quote strings that contain special chars or look like numbers
      if value:match('^#') or value:match('^%d') or value:match('[:%s]') then
        table.insert(lines, prefix .. key .. ': "' .. value .. '"')
      else
        table.insert(lines, prefix .. key .. ': ' .. value)
      end
    else
      table.insert(lines, prefix .. key .. ': ' .. tostring(value))
    end
  end

  return table.concat(lines, '\n')
end

return M
