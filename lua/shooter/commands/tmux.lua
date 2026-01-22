-- Tmux wrapper command registration for shooter.nvim

local M = {}

function M.setup()
  local wrapper = require('shooter.tmux.wrapper')

  vim.api.nvim_create_user_command('ShooterTmuxZoom', wrapper.zoom_toggle,
    { desc = 'Toggle tmux pane zoom' })
  vim.api.nvim_create_user_command('ShooterTmuxEdit', wrapper.edit_in_vim,
    { desc = 'Edit tmux pane content in vim' })
  vim.api.nvim_create_user_command('ShooterTmuxGit', wrapper.git_status_toggle,
    { desc = 'Toggle tmux git status display' })
  vim.api.nvim_create_user_command('ShooterTmuxLight', wrapper.lightswitch,
    { desc = 'Toggle tmux light/dark theme' })
  vim.api.nvim_create_user_command('ShooterTmuxKillOthers', wrapper.kill_other_panes,
    { desc = 'Kill all tmux panes except current' })
  vim.api.nvim_create_user_command('ShooterTmuxReload', wrapper.reload_session,
    { desc = 'Reload tmuxp session' })
  vim.api.nvim_create_user_command('ShooterTmuxDelete', wrapper.delete_session,
    { desc = 'Delete tmux session picker' })
  vim.api.nvim_create_user_command('ShooterTmuxSmug', wrapper.smug_load,
    { desc = 'Load smug session' })
  vim.api.nvim_create_user_command('ShooterTmuxYank', wrapper.yank_to_vim,
    { desc = 'Yank tmux pane content to vim' })
  vim.api.nvim_create_user_command('ShooterTmuxChoose', wrapper.choose_session,
    { desc = 'Choose tmux session/tree' })
  vim.api.nvim_create_user_command('ShooterTmuxSwitch', wrapper.switch_last,
    { desc = 'Switch to last tmux client' })
end

return M
