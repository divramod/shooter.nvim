-- External YAML-based configuration for shooter.nvim
-- Handles global (~/.config/hal/util/shooter/nvim/) and project-local
-- (.hal/util/shooter/cfg/nvim/) config with deep merge, caching, and auto-reload on save.

local utils = require('shooter.utils')

local M = {}

-- Default configuration values (YAML schema)
M.DEFAULTS = {
  file = {
    closed_shots_postfix = {
      color_bg = '',
      color_fg = '#888888',
    },
    closed_shots_prefix = {
      color_bg = '',
      color_fg = '#888888',
    },
    closed_shots_title = {
      color_bg = '#dcedc8',
      color_fg = '#555555',
    },
    first_shot_of_the_day_postfix = {
      color_bg = '',
      color_fg = '#888888',
    },
    first_shot_of_the_day_prefix = {
      color_bg = '',
      color_fg = '#888888',
    },
    first_shot_of_the_day_title = {
      color_bg = '#f0e4d0',
      color_fg = '#555555',
    },
    open_shots = {
      color_bg = '#ffb347',
      color_fg = '#000000',
    },
    open_shots_title = {
      color_bg = '#ffe0a3',
      color_fg = '#333333',
    },
    stats_notification = {
      enabled = true,
    },
  },
}

-- Cached merged config (invalidated by reload())
local _cache = nil

-- Base directory for global config
function M.base_dir()
  return utils.expand_path('~/.config/hal/util/shooter/nvim')
end

-- Sessions directory
function M.sessions_dir()
  return M.base_dir() .. '/sessions'
end

-- Bullets directory for sent shot files
function M.bullets_dir()
  return M.base_dir() .. '/bullets'
end

-- Tmp directory (legacy, kept for migration)
function M.tmp_dir()
  return M.base_dir() .. '/tmp'
end

-- Filter state file path
function M.filter_state_path()
  return M.base_dir() .. '/filter-state.json'
end

-- Last shotfile path for a given repo slug
function M.last_shotfile_path(slug)
  return M.base_dir() .. '/last-shotfile-' .. slug
end

-- Global config.yaml path
function M.global_config_path()
  return M.base_dir() .. '/config.yaml'
end

-- Project-local config.yaml path (relative to git root)
function M.local_config_path()
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error ~= 0 or #git_root == 0 then return nil end
  return git_root[1] .. '/.hal/util/shooter/cfg/nvim/config.yaml'
end

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
        -- String: strip surrounding quotes if present
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

--- Ensure global config.yaml exists with defaults
function M.ensure_global_config()
  local path = M.global_config_path()
  if utils.file_exists(path) then return end
  utils.ensure_dir(utils.get_dirname(path))
  local content = '# Shooter.nvim global configuration\n'
    .. '# Edit this file to customize behavior across all projects.\n'
    .. '# Project-local overrides go to <repo>/.hal/util/shooter/cfg/nvim/config.yaml\n'
    .. M.serialize_yaml(M.DEFAULTS) .. '\n'
  utils.write_file(path, content)
end

--- Ensure project-local config.yaml exists with defaults
function M.ensure_local_config()
  local path = M.local_config_path()
  if not path then return nil end
  if utils.file_exists(path) then return path end
  utils.ensure_dir(utils.get_dirname(path))
  local content = '# Shooter.nvim project-local configuration\n'
    .. '# Values here override the global config at ~/.config/hal/util/shooter/nvim/config.yaml\n'
    .. M.serialize_yaml(M.DEFAULTS) .. '\n'
  utils.write_file(path, content)
  return path
end

--- Fix empty tables that should be leaf values (YAML parser ambiguity)
--- When YAML has `key: ` (empty value), the parser creates {} but the default might be '' or other type.
---@param merged table Merged config
---@param defaults table DEFAULTS schema
local function fix_empty_table_leaves(merged, defaults)
  for key, default_val in pairs(defaults) do
    local merged_val = merged[key]
    if merged_val == nil then
      -- skip
    elseif type(default_val) == 'table' and type(merged_val) == 'table' then
      fix_empty_table_leaves(merged_val, default_val)
    elseif type(default_val) ~= 'table' and type(merged_val) == 'table' and next(merged_val) == nil then
      -- Empty table {} where default is a non-table (e.g., string ''): restore default
      merged[key] = default_val
    end
  end
end

--- Load and merge config: defaults < global YAML < local YAML
--- Result is cached until reload() is called.
---@return table Merged configuration
function M.load()
  if _cache then return _cache end

  -- Run migration on first access (pcall: safe during early startup)
  pcall(M.migrate)
  pcall(M.ensure_global_config)

  local merged = vim.deepcopy(M.DEFAULTS)

  -- Layer 1: global YAML
  local ok, global_content = pcall(utils.read_file, M.global_config_path())
  if ok and global_content then
    local parse_ok, global_parsed = pcall(M.parse_yaml, global_content)
    if parse_ok and type(global_parsed) == 'table' then
      merged = vim.tbl_deep_extend('force', merged, global_parsed)
    end
  end

  -- Layer 2: project-local YAML
  local lok, local_path = pcall(M.local_config_path)
  if lok and local_path then
    local rok, local_content = pcall(utils.read_file, local_path)
    if rok and local_content then
      local parse_ok, local_parsed = pcall(M.parse_yaml, local_content)
      if parse_ok and type(local_parsed) == 'table' then
        merged = vim.tbl_deep_extend('force', merged, local_parsed)
      end
    end
  end

  -- Fix YAML parser ambiguity: empty value `key: ` parses as {} but may be ''
  fix_empty_table_leaves(merged, M.DEFAULTS)

  _cache = merged
  return _cache
end

--- Get a config value by dot path (e.g., 'file.first_shot_of_the_day.color_bg')
---@param dot_path string Dot-separated path
---@return any Value at path, or nil
function M.get(dot_path)
  local cfg = M.load()
  for part in dot_path:gmatch('[^.]+') do
    if type(cfg) ~= 'table' then return nil end
    cfg = cfg[part]
  end
  return cfg
end

--- Invalidate cache and force reload on next access
function M.reload()
  _cache = nil
end

--- Strip keys from tbl that don't exist in schema (recursive)
---@param tbl table Parsed config
---@param schema table DEFAULTS schema
---@return table Cleaned config with only valid keys
local function strip_to_schema(tbl, schema)
  local cleaned = {}
  for key, value in pairs(tbl) do
    if schema[key] ~= nil then
      if type(value) == 'table' and type(schema[key]) == 'table' then
        cleaned[key] = strip_to_schema(value, schema[key])
      else
        cleaned[key] = value
      end
    end
  end
  return cleaned
end

--- Fill missing keys from schema into tbl (recursive)
---@param tbl table Parsed config
---@param schema table DEFAULTS schema
---@return table Config with missing keys filled from defaults
local function fill_from_schema(tbl, schema)
  local result = vim.deepcopy(tbl)
  for key, value in pairs(schema) do
    if result[key] == nil then
      result[key] = vim.deepcopy(value)
    elseif type(result[key]) == 'table' and type(value) == 'table' then
      result[key] = fill_from_schema(result[key], value)
    end
  end
  return result
end

--- Count leaf (non-table) keys recursively
local function count_leaves(tbl)
  local n = 0
  for _, v in pairs(tbl) do
    if type(v) == 'table' then
      n = n + count_leaves(v)
    else
      n = n + 1
    end
  end
  return n
end

--- Fix a config.yaml file: strip invalid keys, optionally fill missing defaults.
--- For global config: adds all missing keys with default values.
--- For local config: only strips invalid keys.
---@param path string Path to config.yaml
---@param is_global boolean Whether this is the global config
---@return number removed Number of leaf keys removed
---@return number added Number of leaf keys added
function M.fix_config(path, is_global)
  if not path or not utils.file_exists(path) then return 0, 0 end
  local content = utils.read_file(path)
  if not content then return 0, 0 end

  local parsed = M.parse_yaml(content)

  -- Strip invalid keys
  local cleaned = strip_to_schema(parsed, M.DEFAULTS)
  local removed = count_leaves(parsed) - count_leaves(cleaned)
  local added = 0

  -- For global: fill missing defaults
  if is_global then
    local before_count = count_leaves(cleaned)
    cleaned = fill_from_schema(cleaned, M.DEFAULTS)
    added = count_leaves(cleaned) - before_count
  end

  -- Write back with header
  local header = is_global
    and '# Shooter.nvim global configuration\n'
      .. '# Edit this file to customize behavior across all projects.\n'
      .. '# Project-local overrides go to <repo>/.hal/util/shooter/cfg/nvim/config.yaml\n'
    or '# Shooter.nvim project-local configuration\n'
      .. '# Values here override the global config at ~/.config/hal/util/shooter/nvim/config.yaml\n'

  utils.write_file(path, header .. M.serialize_yaml(cleaned) .. '\n')
  M.reload()
  return removed, added
end

--- Fix config in a buffer: strip invalid keys, fill missing defaults (global).
--- Updates buffer lines directly (no disk write, no W12 warnings).
---@param bufnr number Buffer number
---@param is_global boolean Whether this is the global config
---@return number removed Number of leaf keys removed
---@return number added Number of leaf keys added
function M.fix_config_buffer(bufnr, is_global)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n')
  local parsed = M.parse_yaml(content)

  -- Strip invalid keys
  local cleaned = strip_to_schema(parsed, M.DEFAULTS)
  local removed = count_leaves(parsed) - count_leaves(cleaned)
  local added = 0

  -- For global: fill missing defaults
  if is_global then
    local before_count = count_leaves(cleaned)
    cleaned = fill_from_schema(cleaned, M.DEFAULTS)
    added = count_leaves(cleaned) - before_count
  end

  if removed == 0 and added == 0 then return 0, 0 end

  -- Build new content and set buffer lines
  local header = is_global
    and '# Shooter.nvim global configuration\n'
      .. '# Edit this file to customize behavior across all projects.\n'
      .. '# Project-local overrides go to <repo>/.hal/util/shooter/cfg/nvim/config.yaml\n'
    or '# Shooter.nvim project-local configuration\n'
      .. '# Values here override the global config at ~/.config/hal/util/shooter/nvim/config.yaml\n'

  local new_content = header .. M.serialize_yaml(cleaned)
  local new_lines = vim.split(new_content, '\n', { plain = true })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  M.reload()
  return removed, added
end

return M
