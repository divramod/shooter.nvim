-- Health check entry — wires the per-area sub-modules into vim.health.
-- Split during plan 0001 phase 004 T006 from the monolithic shooter/health.lua.

local plugins = require('shooter.health.plugins')
local system = require('shooter.health.system')
local context = require('shooter.health.context')
local shotfile = require('shooter.health.shotfile')
local tools = require('shooter.health.tools')

local M = {}

-- Public re-export of every check so tests + downstream callers keep
-- the same surface they had pre-split. Mirrors the M._checks table from
-- the pre-split file.
M._checks = {
  telescope = plugins.check_telescope,
  oil_nvim = plugins.check_oil_nvim,
  vim_tmux_navigator = plugins.check_vim_tmux_navigator,
  gp_nvim = plugins.check_gp_nvim,
  iterm = system.check_iterm,
  tmux_installed = system.check_tmux_installed,
  in_tmux = system.check_in_tmux,
  claude_process = system.check_claude_process,
  global_context = context.check_global_context,
  project_context = context.check_project_context,
  prompts_directory = shotfile.check_prompts_directory,
  queue_file = shotfile.check_queue_file,
}

function M.check()
  vim.health.start('shooter.nvim')

  local shooter = require('shooter')
  if not shooter.is_initialized() then
    vim.health.warn('shooter.nvim is not initialized', {
      'Call require("shooter").setup() in your config',
      'See :help shooter.nvim for setup instructions',
    })
    local config = require('shooter.config')
    if not config.current or not config.current.paths then
      vim.health.error('Config module failed to initialize')
      return
    end
  end

  vim.health.start('Configuration')
  local utils = require('shooter.utils')
  local config_path = utils.find_config_file()
  if config_path then
    vim.health.ok('Config file: ' .. config_path)
  else
    vim.health.info('Config file not found (searched ~/.config/nvim/lua/plugins/)')
  end

  vim.health.start('Neovim Plugins')
  plugins.check_telescope()
  plugins.check_oil_nvim()
  plugins.check_vim_tmux_navigator()
  plugins.check_gp_nvim()

  vim.health.start('System Dependencies')
  system.check_iterm()
  tools.check_hal_cli()
  tools.check_python()
  tools.check_ttok()
  local tmux_installed = system.check_tmux_installed()

  if tmux_installed then
    vim.health.start('Tmux Environment')
    local in_tmux = system.check_in_tmux()
    if in_tmux then
      system.check_claude_process()
    end
  end

  vim.health.start('Context Files')
  context.check_global_context()
  context.check_project_context()

  vim.health.start('Directory Structure')
  shotfile.check_prompts_directory()

  vim.health.start('Queue System')
  shotfile.check_queue_file()

  vim.health.start('Summary')
  vim.health.info('Run :help shooter.nvim for usage documentation')
end

return M
