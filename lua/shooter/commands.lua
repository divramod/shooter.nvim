-- Command registration for shooter.nvim
-- Extracted from next-action.lua

local M = {}

-- Setup all vim commands
function M.setup()
  -- Core shot management commands
  vim.api.nvim_create_user_command('ShooterCreate', function(opts)
    local files = require('shooter.core.files')
    local title = opts.args ~= '' and opts.args or 'New Shot File'
    local path, filename = files.create_file(title)
    if path then
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    end
  end, { nargs = '?', desc = 'Create new shooter file' })

  vim.api.nvim_create_user_command('ShooterList', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_files()
    if picker then
      picker:find()
    end
  end, { desc = 'List all shooter files with Telescope' })

  vim.api.nvim_create_user_command('ShooterOpenShots', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then
      picker:find()
    end
  end, { desc = 'List open shots in current file' })

  vim.api.nvim_create_user_command('ShooterHelp', function()
    -- TODO: Implement help display
    vim.notify('ShooterHelp not yet implemented', vim.log.levels.INFO)
  end, { desc = 'Show shooter help' })

  vim.api.nvim_create_user_command('ShooterInbox', function()
    local cwd = vim.fn.getcwd()
    local inbox_path = cwd .. '/INBOX.md'
    if vim.fn.filereadable(inbox_path) ~= 1 then
      local file = io.open(inbox_path, 'w')
      if file then
        file:write('# Inbox\n\n')
        file:close()
      end
    end
    vim.cmd('edit ' .. inbox_path)
  end, { desc = 'Open INBOX.md in repo root' })

  vim.api.nvim_create_user_command('ShooterLast', function()
    local files = require('shooter.core.files')
    local last_file = files.get_last_edited_file()
    if last_file then
      vim.cmd('edit ' .. vim.fn.fnameescape(last_file))
    end
  end, { desc = 'Open last edited shooter file' })

  vim.api.nvim_create_user_command('ShooterNewShot', function()
    local shots = require('shooter.core.shots')
    shots.create_new_shot()
  end, { desc = 'Create new shot in current file' })

  vim.api.nvim_create_user_command('ShooterNewShotWhisper', function()
    local shots = require('shooter.core.shots')
    shots.create_new_shot_with_whisper()
  end, { desc = 'Create new shot and start whisper' })

  vim.api.nvim_create_user_command('ShooterDeleteLastShot', function()
    local shots = require('shooter.core.shots')
    shots.delete_last_shot()
  end, { desc = 'Delete the last created shot' })

  -- Movement commands
  vim.api.nvim_create_user_command('ShooterArchive', function()
    local files = require('shooter.core.files')
    files.move_file_to_folder('archive')
  end, { desc = 'Move file to archive folder' })

  vim.api.nvim_create_user_command('ShooterBacklog', function()
    local files = require('shooter.core.files')
    files.move_file_to_folder('backlog')
  end, { desc = 'Move file to backlog folder' })

  vim.api.nvim_create_user_command('ShooterDone', function()
    local files = require('shooter.core.files')
    files.move_file_to_folder('done')
  end, { desc = 'Move file to done folder' })

  vim.api.nvim_create_user_command('ShooterReqs', function()
    local files = require('shooter.core.files')
    files.move_file_to_folder('reqs')
  end, { desc = 'Move file to reqs folder' })

  vim.api.nvim_create_user_command('ShooterTest', function()
    local files = require('shooter.core.files')
    files.move_file_to_folder('test')
  end, { desc = 'Move file to test folder' })

  vim.api.nvim_create_user_command('ShooterWait', function()
    local files = require('shooter.core.files')
    files.move_file_to_folder('wait')
  end, { desc = 'Move file to wait folder' })

  vim.api.nvim_create_user_command('ShooterPrompts', function()
    local files = require('shooter.core.files')
    files.move_file_to_folder('')
  end, { desc = 'Move file to prompts (in-progress)' })

  vim.api.nvim_create_user_command('ShooterGitRoot', function()
    local files = require('shooter.core.files')
    files.move_to_git_root()
  end, { desc = 'Move file to git root' })

  -- Send commands (1-9)
  for i = 1, 9 do
    vim.api.nvim_create_user_command('ShooterSend' .. i, function()
      local tmux = require('shooter.tmux')
      tmux.send_current_shot(i)
    end, { desc = 'Send current shot to pane ' .. i })

    vim.api.nvim_create_user_command('ShooterSendAll' .. i, function()
      local tmux = require('shooter.tmux')
      tmux.send_all_shots(i)
    end, { desc = 'Send all open shots to pane ' .. i })

    vim.api.nvim_create_user_command('ShooterSendVisual' .. i, function(opts)
      local tmux = require('shooter.tmux')
      local start_line = opts.line1
      local end_line = opts.line2
      tmux.send_visual_selection(i, start_line, end_line)
    end, { range = true, desc = 'Send visual selection to pane ' .. i })
  end

  -- Queue commands (1-4)
  for i = 1, 4 do
    vim.api.nvim_create_user_command('ShooterQueueAdd' .. i, function()
      local queue = require('shooter.queue')
      queue.add_to_queue(nil, i)
    end, { desc = 'Add current shot to queue for pane ' .. i })
  end

  vim.api.nvim_create_user_command('ShooterQueueView', function()
    local queue_picker = require('shooter.queue.picker')
    queue_picker.show_queue()
  end, { desc = 'View shot queue' })

  vim.api.nvim_create_user_command('ShooterQueueClear', function()
    local queue = require('shooter.queue')
    queue.clear_queue()
  end, { desc = 'Clear shot queue' })

  -- Other commands
  vim.api.nvim_create_user_command('ShooterImages', function()
    -- TODO: Implement image insertion
    vim.notify('ShooterImages not yet implemented', vim.log.levels.INFO)
  end, { desc = 'Insert image references' })

  vim.api.nvim_create_user_command('ShooterPrdList', function()
    -- TODO: Implement PRD list picker
    vim.notify('ShooterPrdList not yet implemented', vim.log.levels.INFO)
  end, { desc = 'List PRD tasks with preview' })

  vim.api.nvim_create_user_command('ShooterOpenPrompts', function()
    local config = require('shooter.config')
    local prompts_dir = config.get('paths.prompts_dir')
    vim.fn.mkdir(prompts_dir, 'p')
    vim.cmd('Oil ' .. prompts_dir)
  end, { desc = 'Open Oil in prompts folder' })
end

return M
