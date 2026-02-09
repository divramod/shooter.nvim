-- External YAML-based configuration for shooter.nvim
-- Handles global (~/.config/shooter/nvim/) and project-local (.shooter/cfg/nvim/) config
-- with deep merge, caching, migration from old paths, and auto-reload on save.

local utils = require('shooter.utils')

local M = {}

-- Default configuration values (YAML schema)
M.DEFAULTS = {
  file = {
    first_shot_color = '#e6d5b8',
    first_shot_debounce_in_ms = 500,
  },
}

-- Cached merged config (invalidated by reload())
local _cache = nil

-- Base directory for global config
function M.base_dir()
  return utils.expand_path('~/.config/shooter/nvim')
end

-- Sessions directory
function M.sessions_dir()
  return M.base_dir() .. '/sessions'
end

-- Tmp directory for temp sendable files
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
  return git_root[1] .. '/.shooter/cfg/nvim/config.yaml'
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
        parent[key] = value:match('^["\'](.+)["\']$') or value
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

  for key, value in pairs(tbl) do
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
    .. '# Project-local overrides go to <repo>/.shooter/cfg/nvim/config.yaml\n\n'
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
    .. '# Values here override the global config at ~/.config/shooter/nvim/config.yaml\n\n'
    .. M.serialize_yaml(M.DEFAULTS) .. '\n'
  utils.write_file(path, content)
  return path
end

--- Migrate from old config directory (~/.config/shooter.nvim/) to new (~/.config/shooter/nvim/)
--- Idempotent: skips if new dir already has content or old dir doesn't exist.
function M.migrate()
  local old_dir = utils.expand_path('~/.config/shooter.nvim')
  local new_dir = M.base_dir()

  if not utils.dir_exists(old_dir) then return end
  if utils.dir_exists(new_dir) then return end

  -- Create new dir and copy contents
  utils.ensure_dir(new_dir)
  vim.fn.system(string.format('cp -a %s/. %s/', vim.fn.shellescape(old_dir), vim.fn.shellescape(new_dir)))

  -- Remove old directory
  vim.fn.delete(old_dir, 'rf')
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

  _cache = merged
  return _cache
end

--- Get a config value by dot path (e.g., 'file.first_shot_color')
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

return M
