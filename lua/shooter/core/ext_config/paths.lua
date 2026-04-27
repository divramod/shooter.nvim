-- ext_config paths — pure path computation for global/local config layout.

local utils = require('shooter.utils')

local M = {}

function M.base_dir()
  return utils.expand_path('~/.config/hal/util/shooter/nvim')
end

function M.sessions_dir()
  return M.base_dir() .. '/sessions'
end

function M.bullets_dir()
  return M.base_dir() .. '/bullets'
end

-- Tmp directory (legacy, kept for migration)
function M.tmp_dir()
  return M.base_dir() .. '/tmp'
end

function M.filter_state_path()
  return M.base_dir() .. '/filter-state.json'
end

function M.last_shotfile_path(slug)
  return M.base_dir() .. '/last-shotfile-' .. slug
end

function M.global_config_path()
  return M.base_dir() .. '/config.yaml'
end

-- Project-local config.yaml path (relative to git root)
function M.local_config_path()
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error ~= 0 or #git_root == 0 then return nil end
  return git_root[1] .. '/.hal/util/shooter/cfg/nvim/config.yaml'
end

return M
