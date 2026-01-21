-- Default keybindings for shooter.nvim
-- Extracted from n-special.lua

local M = {}

-- Setup default keymaps
function M.setup()
  local config = require('shooter.config')

  -- Check if keymaps are enabled
  if not config.get('keymaps.enabled') then
    return
  end

  local prefix = config.get('keymaps.prefix')
  local move_prefix = config.get('keymaps.move_prefix')
  local opts = { noremap = true, silent = true }

  -- Core commands
  vim.keymap.set('n', prefix .. 'd', ':ShooterDeleteLastShot<cr>',
    vim.tbl_extend('force', opts, { desc = 'Delete last shot' }))

  vim.keymap.set('n', prefix .. 'S', ':ShooterNewShotWhisper<cr>',
    vim.tbl_extend('force', opts, { desc = 'New shot + whisper' }))

  vim.keymap.set('n', prefix .. 'eg', ':ShooterEditGlobalContext<cr>',
    vim.tbl_extend('force', opts, { desc = 'Edit global context' }))

  vim.keymap.set('n', prefix .. 'ep', ':ShooterEditProjectContext<cr>',
    vim.tbl_extend('force', opts, { desc = 'Edit project context' }))

  vim.keymap.set('n', prefix .. 'g', ':ShooterImages<cr>',
    vim.tbl_extend('force', opts, { desc = 'Get images' }))

  vim.keymap.set('n', prefix .. 'h', ':ShooterHelp<cr>',
    vim.tbl_extend('force', opts, { desc = 'Help' }))

  vim.keymap.set('n', prefix .. 'i', ':ShooterOpenHistory<cr>',
    vim.tbl_extend('force', opts, { desc = 'History (Oil)' }))

  vim.keymap.set('n', prefix .. 'l', ':ShooterLast<cr>',
    vim.tbl_extend('force', opts, { desc = 'Last file' }))

  vim.keymap.set('n', prefix .. 'n', ':ShooterCreate<cr>',
    vim.tbl_extend('force', opts, { desc = 'New' }))

  vim.keymap.set('n', prefix .. 'o', ':ShooterOpenShots<cr>',
    vim.tbl_extend('force', opts, { desc = 'Open shots picker' }))

  vim.keymap.set('n', prefix .. 's', ':ShooterNewShot<cr>',
    vim.tbl_extend('force', opts, { desc = 'New shot' }))

  vim.keymap.set('n', prefix .. 't', ':ShooterList<cr>',
    vim.tbl_extend('force', opts, { desc = 'Telescope list' }))

  vim.keymap.set('n', prefix .. 'p', ':ShooterOpenPrompts<cr>',
    vim.tbl_extend('force', opts, { desc = 'Oil prompts folder' }))

  vim.keymap.set('n', prefix .. 'P', ':ShooterPrdList<cr>',
    vim.tbl_extend('force', opts, { desc = 'PRD list tasks' }))

  -- Shot navigation
  vim.keymap.set('n', prefix .. ']', ':ShooterNextShot<cr>',
    vim.tbl_extend('force', opts, { desc = 'Next open shot' }))

  vim.keymap.set('n', prefix .. '[', ':ShooterPrevShot<cr>',
    vim.tbl_extend('force', opts, { desc = 'Previous open shot' }))

  vim.keymap.set('n', prefix .. '.', ':ShooterToggleDone<cr>',
    vim.tbl_extend('force', opts, { desc = 'Toggle shot done' }))

  vim.keymap.set('n', prefix .. 'L', ':ShooterLatestSent<cr>',
    vim.tbl_extend('force', opts, { desc = 'Latest sent shot' }))

  vim.keymap.set('n', prefix .. 'u', ':ShooterUndoLatestSent<cr>',
    vim.tbl_extend('force', opts, { desc = 'Undo latest sent marking' }))

  vim.keymap.set('n', prefix .. 'H', ':ShooterHealth<cr>',
    vim.tbl_extend('force', opts, { desc = 'Health check' }))

  vim.keymap.set('n', prefix .. 'A', ':ShooterAnalyticsGlobal<cr>',
    vim.tbl_extend('force', opts, { desc = 'Global analytics' }))

  vim.keymap.set('n', prefix .. 'a', ':ShooterAnalyticsProject<cr>',
    vim.tbl_extend('force', opts, { desc = 'Project analytics' }))

  -- Move commands (with move_prefix, e.g., <space>m)
  vim.keymap.set('n', prefix .. move_prefix .. 'a', ':ShooterArchive<cr>',
    vim.tbl_extend('force', opts, { desc = '→ archive' }))

  vim.keymap.set('n', prefix .. move_prefix .. 'b', ':ShooterBacklog<cr>',
    vim.tbl_extend('force', opts, { desc = '→ backlog' }))

  vim.keymap.set('n', prefix .. move_prefix .. 'd', ':ShooterDone<cr>',
    vim.tbl_extend('force', opts, { desc = '→ done' }))

  vim.keymap.set('n', prefix .. move_prefix .. 'g', ':ShooterGitRoot<cr>',
    vim.tbl_extend('force', opts, { desc = '→ git root' }))

  vim.keymap.set('n', prefix .. move_prefix .. 'p', ':ShooterPrompts<cr>',
    vim.tbl_extend('force', opts, { desc = '→ prompts' }))

  vim.keymap.set('n', prefix .. move_prefix .. 'r', ':ShooterReqs<cr>',
    vim.tbl_extend('force', opts, { desc = '→ reqs' }))

  vim.keymap.set('n', prefix .. move_prefix .. 't', ':ShooterTest<cr>',
    vim.tbl_extend('force', opts, { desc = '→ test' }))

  vim.keymap.set('n', prefix .. move_prefix .. 'w', ':ShooterWait<cr>',
    vim.tbl_extend('force', opts, { desc = '→ wait' }))

  -- Send to claude (single shot) - panes 1-4
  for i = 1, 4 do
    vim.keymap.set('n', prefix .. tostring(i), ':ShooterSend' .. i .. '<cr>',
      vim.tbl_extend('force', opts, { desc = 'Send to claude #' .. i }))
  end

  -- Send ALL open shots - double space prefix
  for i = 1, 4 do
    vim.keymap.set('n', prefix .. prefix .. tostring(i), ':ShooterSendAll' .. i .. '<cr>',
      vim.tbl_extend('force', opts, { desc = 'Send ALL to claude #' .. i }))
  end

  -- Queue commands
  for i = 1, 4 do
    vim.keymap.set('n', prefix .. 'q' .. tostring(i), ':ShooterQueueAdd' .. i .. '<cr>',
      vim.tbl_extend('force', opts, { desc = 'Queue for pane #' .. i }))
  end

  vim.keymap.set('n', prefix .. 'Q', ':ShooterQueueView<cr>',
    vim.tbl_extend('force', opts, { desc = 'View queue' }))

  -- Resend latest shot commands (1-4)
  for i = 1, 4 do
    vim.keymap.set('n', prefix .. 'r' .. tostring(i), ':ShooterResend' .. i .. '<cr>',
      vim.tbl_extend('force', opts, { desc = 'Resend latest to pane #' .. i }))
  end

  -- Visual mode send commands (1-4)
  for i = 1, 4 do
    vim.keymap.set('v', prefix .. tostring(i), ':ShooterSendVisual' .. i .. '<cr>',
      vim.tbl_extend('force', opts, { desc = 'Send selection to pane ' .. i }))
  end
end

return M
