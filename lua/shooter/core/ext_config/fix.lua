-- ext_config fix — strip-to-schema / fill-from-schema repair for config.yaml.

local utils = require('shooter.utils')
local yaml = require('shooter.core.ext_config.yaml')
local load_mod = require('shooter.core.ext_config.load')

local M = {}

-- Strip keys from tbl that don't exist in schema (recursive).
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

-- Fill missing keys from schema into tbl (recursive).
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

local GLOBAL_HEADER = '# Shooter.nvim global configuration\n'
  .. '# Edit this file to customize behavior across all projects.\n'
  .. '# Project-local overrides go to <repo>/.hal/util/shooter/cfg/nvim/config.yaml\n'

local LOCAL_HEADER = '# Shooter.nvim project-local configuration\n'
  .. '# Values here override the global config at ~/.config/hal/util/shooter/nvim/config.yaml\n'

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

  local parsed = yaml.parse_yaml(content)
  local cleaned = strip_to_schema(parsed, load_mod.DEFAULTS)
  local removed = count_leaves(parsed) - count_leaves(cleaned)
  local added = 0

  if is_global then
    local before_count = count_leaves(cleaned)
    cleaned = fill_from_schema(cleaned, load_mod.DEFAULTS)
    added = count_leaves(cleaned) - before_count
  end

  local header = is_global and GLOBAL_HEADER or LOCAL_HEADER
  utils.write_file(path, header .. yaml.serialize_yaml(cleaned) .. '\n')
  load_mod.reload()
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
  local parsed = yaml.parse_yaml(content)

  local cleaned = strip_to_schema(parsed, load_mod.DEFAULTS)
  local removed = count_leaves(parsed) - count_leaves(cleaned)
  local added = 0

  if is_global then
    local before_count = count_leaves(cleaned)
    cleaned = fill_from_schema(cleaned, load_mod.DEFAULTS)
    added = count_leaves(cleaned) - before_count
  end

  if removed == 0 and added == 0 then return 0, 0 end

  local header = is_global and GLOBAL_HEADER or LOCAL_HEADER
  local new_content = header .. yaml.serialize_yaml(cleaned)
  local new_lines = vim.split(new_content, '\n', { plain = true })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  load_mod.reload()
  return removed, added
end

return M
