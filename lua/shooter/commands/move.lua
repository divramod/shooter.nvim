-- Movement command registration for shooter.nvim

local M = {}

function M.setup()
  local movement = require('shooter.core.movement')

  vim.api.nvim_create_user_command('ShooterArchive', movement.move_to_archive, { desc = '→ archive' })
  vim.api.nvim_create_user_command('ShooterBacklog', movement.move_to_backlog, { desc = '→ backlog' })
  vim.api.nvim_create_user_command('ShooterDone', movement.move_to_done, { desc = '→ done' })
  vim.api.nvim_create_user_command('ShooterReqs', movement.move_to_reqs, { desc = '→ reqs' })
  vim.api.nvim_create_user_command('ShooterTest', movement.move_to_test, { desc = '→ test' })
  vim.api.nvim_create_user_command('ShooterWait', movement.move_to_wait, { desc = '→ wait' })
  vim.api.nvim_create_user_command('ShooterPrompts', movement.move_to_prompts, { desc = '→ prompts' })
  vim.api.nvim_create_user_command('ShooterGitRoot', movement.move_to_git_root, { desc = '→ git root' })
end

return M
