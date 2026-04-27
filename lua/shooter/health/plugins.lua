-- Plugin dependency checks (telescope, oil, tmux navigator, gp.nvim).
-- Pulled out of shooter/health.lua during plan 0001 phase 004 T006.

local M = {}

function M.check_telescope()
  local ok, _ = pcall(require, 'telescope')
  if not ok then
    vim.health.error('Telescope not found', {
      'Install telescope.nvim: https://github.com/nvim-telescope/telescope.nvim',
    })
    return false
  end
  vim.health.ok('Telescope is installed (https://github.com/nvim-telescope/telescope.nvim)')
  return true
end

function M.check_oil_nvim()
  local ok = pcall(require, 'oil')
  if not ok then
    vim.health.error('oil.nvim not found', {
      'Install oil.nvim: https://github.com/stevearc/oil.nvim',
      'Required for file management and movement commands',
    })
    return false
  end
  vim.health.ok('oil.nvim is installed (https://github.com/stevearc/oil.nvim)')
  return true
end

function M.check_vim_tmux_navigator()
  local has_plugin = vim.fn.exists(':TmuxNavigateLeft') == 2
  if not has_plugin then
    vim.health.error('vim-i3wm-tmux-navigator not found', {
      'Install vim-i3wm-tmux-navigator: https://github.com/fogine/vim-i3wm-tmux-navigator',
      'Required for seamless navigation between vim splits and tmux panes',
    })
    return false
  end
  vim.health.ok('vim-i3wm-tmux-navigator is installed (https://github.com/fogine/vim-i3wm-tmux-navigator)')
  return true
end

function M.check_gp_nvim()
  local has_gp = vim.fn.exists(':GpWhisper') == 2
  if not has_gp then
    vim.health.info('gp.nvim (GpWhisper) not found', {
      'Optional: Install gp.nvim for voice dictation with <space>e',
      'https://github.com/Robitx/gp.nvim',
    })
    return false
  end
  vim.health.ok('gp.nvim (GpWhisper) is available (https://github.com/Robitx/gp.nvim)')
  return true
end

return M
