-- ext_config load — DEFAULTS schema, ensure_*_config, load/get/reload + cache.

local utils = require('shooter.utils')
local paths = require('shooter.core.ext_config.paths')
local yaml = require('shooter.core.ext_config.yaml')

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

function M.ensure_global_config()
  local path = paths.global_config_path()
  if utils.file_exists(path) then return end
  utils.ensure_dir(utils.get_dirname(path))
  local content = '# Shooter.nvim global configuration\n'
    .. '# Edit this file to customize behavior across all projects.\n'
    .. '# Project-local overrides go to <repo>/.hal/util/shooter/cfg/nvim/config.yaml\n'
    .. yaml.serialize_yaml(M.DEFAULTS) .. '\n'
  utils.write_file(path, content)
end

function M.ensure_local_config()
  local path = paths.local_config_path()
  if not path then return nil end
  if utils.file_exists(path) then return path end
  utils.ensure_dir(utils.get_dirname(path))
  local content = '# Shooter.nvim project-local configuration\n'
    .. '# Values here override the global config at ~/.config/hal/util/shooter/nvim/config.yaml\n'
    .. yaml.serialize_yaml(M.DEFAULTS) .. '\n'
  utils.write_file(path, content)
  return path
end

-- YAML parser ambiguity: `key: ` (empty value) becomes {} but the schema may
-- declare a non-table leaf. Walk both trees and restore the default.
local function fix_empty_table_leaves(merged, defaults)
  for key, default_val in pairs(defaults) do
    local merged_val = merged[key]
    if merged_val == nil then
      -- skip
    elseif type(default_val) == 'table' and type(merged_val) == 'table' then
      fix_empty_table_leaves(merged_val, default_val)
    elseif type(default_val) ~= 'table' and type(merged_val) == 'table' and next(merged_val) == nil then
      merged[key] = default_val
    end
  end
end

--- Load and merge config: defaults < global YAML < local YAML.
--- Result is cached until reload() is called.
function M.load() -- audited: function definition, not loadstring/load() exec
  if _cache then return _cache end

  -- Forward-compat hook; pcall keeps load() safe before migration is wired up.
  pcall(M.migrate)
  pcall(M.ensure_global_config)

  local merged = vim.deepcopy(M.DEFAULTS)

  -- Layer 1: global YAML
  local ok, global_content = pcall(utils.read_file, paths.global_config_path())
  if ok and global_content then
    local parse_ok, global_parsed = pcall(yaml.parse_yaml, global_content)
    if parse_ok and type(global_parsed) == 'table' then
      merged = vim.tbl_deep_extend('force', merged, global_parsed)
    end
  end

  -- Layer 2: project-local YAML
  local lok, local_path = pcall(paths.local_config_path)
  if lok and local_path then
    local rok, local_content = pcall(utils.read_file, local_path)
    if rok and local_content then
      local parse_ok, local_parsed = pcall(yaml.parse_yaml, local_content)
      if parse_ok and type(local_parsed) == 'table' then
        merged = vim.tbl_deep_extend('force', merged, local_parsed)
      end
    end
  end

  fix_empty_table_leaves(merged, M.DEFAULTS)

  _cache = merged
  return _cache
end

--- Get a config value by dot path (e.g., 'file.first_shot_of_the_day.color_bg')
function M.get(dot_path)
  local cfg = M.load() -- audited: M.load is shooter.core.ext_config.load, not loadstring
  for part in dot_path:gmatch('[^.]+') do
    if type(cfg) ~= 'table' then return nil end
    cfg = cfg[part]
  end
  return cfg
end

function M.reload()
  _cache = nil
end

return M
