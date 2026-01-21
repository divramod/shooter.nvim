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
    if picker then picker:find() end
  end, { desc = 'List all shooter files with Telescope' })

  vim.api.nvim_create_user_command('ShooterOpenShots', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then picker:find() end
  end, { desc = 'List open shots in current file' })

  vim.api.nvim_create_user_command('ShooterHelp', function()
    require('shooter.help').show()
  end, { desc = 'Show shooter help' })

  vim.api.nvim_create_user_command('ShooterInbox', function()
    local cwd = vim.fn.getcwd()
    local inbox_path = cwd .. '/INBOX.md'
    if vim.fn.filereadable(inbox_path) ~= 1 then
      local file = io.open(inbox_path, 'w')
      if file then file:write('# Inbox\n\n'); file:close() end
    end
    vim.cmd('edit ' .. inbox_path)
  end, { desc = 'Open INBOX.md in repo root' })

  vim.api.nvim_create_user_command('ShooterLast', function()
    local files = require('shooter.core.files')
    local last_file = files.get_last_edited_file()
    if last_file then vim.cmd('edit ' .. vim.fn.fnameescape(last_file)) end
  end, { desc = 'Open last edited shooter file' })

  vim.api.nvim_create_user_command('ShooterNewShot', function()
    require('shooter.core.shot_actions').create_new_shot()
  end, { desc = 'Create new shot in current file' })

  vim.api.nvim_create_user_command('ShooterNewShotWhisper', function()
    require('shooter.core.shot_actions').create_new_shot_with_whisper()
  end, { desc = 'Create new shot and start whisper' })

  vim.api.nvim_create_user_command('ShooterDeleteLastShot', function()
    require('shooter.core.shot_actions').delete_last_shot()
  end, { desc = 'Delete the last created shot' })

  vim.api.nvim_create_user_command('ShooterNextShot', function()
    require('shooter.core.shot_actions').goto_next_open_shot()
  end, { desc = 'Go to next open shot' })

  vim.api.nvim_create_user_command('ShooterPrevShot', function()
    require('shooter.core.shot_actions').goto_prev_open_shot()
  end, { desc = 'Go to previous open shot' })

  vim.api.nvim_create_user_command('ShooterToggleDone', function()
    require('shooter.core.shot_actions').toggle_shot_done()
  end, { desc = 'Toggle shot done status' })

  vim.api.nvim_create_user_command('ShooterLatestSent', function()
    require('shooter.core.shot_actions').goto_latest_sent_shot()
  end, { desc = 'Go to latest sent shot' })

  vim.api.nvim_create_user_command('ShooterUndoLatestSent', function()
    require('shooter.core.shot_actions').undo_latest_sent_shot()
  end, { desc = 'Undo marking of latest sent shot' })

  vim.api.nvim_create_user_command('ShooterPrevSent', function()
    require('shooter.core.shot_actions').goto_prev_sent_shot()
  end, { desc = 'Go to previous (older) sent shot' })

  vim.api.nvim_create_user_command('ShooterNextSent', function()
    require('shooter.core.shot_actions').goto_next_sent_shot()
  end, { desc = 'Go to next (newer) sent shot' })

  vim.api.nvim_create_user_command('ShooterHealth', function()
    vim.cmd('checkhealth shooter')
  end, { desc = 'Run shooter health check' })

  -- Movement commands
  local function move_cmd(folder)
    return function()
      require('shooter.core.files').move_file_to_folder(folder)
    end
  end

  vim.api.nvim_create_user_command('ShooterArchive', move_cmd('archive'), { desc = '→ archive' })
  vim.api.nvim_create_user_command('ShooterBacklog', move_cmd('backlog'), { desc = '→ backlog' })
  vim.api.nvim_create_user_command('ShooterDone', move_cmd('done'), { desc = '→ done' })
  vim.api.nvim_create_user_command('ShooterReqs', move_cmd('reqs'), { desc = '→ reqs' })
  vim.api.nvim_create_user_command('ShooterTest', move_cmd('test'), { desc = '→ test' })
  vim.api.nvim_create_user_command('ShooterWait', move_cmd('wait'), { desc = '→ wait' })
  vim.api.nvim_create_user_command('ShooterPrompts', move_cmd(''), { desc = '→ prompts' })

  vim.api.nvim_create_user_command('ShooterGitRoot', function()
    require('shooter.core.files').move_to_git_root()
  end, { desc = 'Move file to git root' })

  -- Other commands
  vim.api.nvim_create_user_command('ShooterImages', function()
    require('shooter.images').insert_images()
  end, { desc = 'Insert image references' })

  vim.api.nvim_create_user_command('ShooterPrdList', function()
    require('shooter.prd').list()
  end, { desc = 'List PRD tasks with preview' })

  vim.api.nvim_create_user_command('ShooterOpenPrompts', function()
    local config = require('shooter.config')
    local prompts_dir = config.get('paths.prompts_dir')
    vim.fn.mkdir(prompts_dir, 'p')
    vim.cmd('Oil ' .. prompts_dir)
  end, { desc = 'Open Oil in prompts folder' })

  vim.api.nvim_create_user_command('ShooterEditGlobalContext', function()
    local config = require('shooter.config')
    local utils = require('shooter.utils')
    local global_path = utils.expand_path(config.get('paths.global_context'))
    vim.fn.mkdir(vim.fn.fnamemodify(global_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(global_path))
  end, { desc = 'Edit global shooter context file' })

  vim.api.nvim_create_user_command('ShooterEditProjectContext', function()
    local config = require('shooter.config')
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local project_path = git_root .. '/' .. config.get('paths.project_context')
    vim.fn.mkdir(vim.fn.fnamemodify(project_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(project_path))
  end, { desc = 'Edit project shooter context file' })

  vim.api.nvim_create_user_command('ShooterEditConfig', function()
    local utils = require('shooter.utils')
    local config_path = utils.find_config_file()
    if not config_path then
      vim.notify('Shooter config file not found. Check ~/.config/nvim/lua/plugins/', vim.log.levels.WARN)
      return
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
  end, { desc = 'Edit shooter.nvim config file' })

  vim.api.nvim_create_user_command('ShooterCreateInRepo', function()
    require('shooter.core.repos').create_in_repo_picker()
  end, { desc = 'Create shot file in any configured repo' })

  vim.api.nvim_create_user_command('ShooterMunition', function()
    require('shooter.inbox.picker').show_file_picker()
  end, { desc = 'Import tasks from inbox files as new shots' })

  -- Analytics commands
  vim.api.nvim_create_user_command('ShooterAnalyticsGlobal', function()
    require('shooter.analytics').show_global()
  end, { desc = 'Show global shot analytics' })

  vim.api.nvim_create_user_command('ShooterAnalyticsProject', function()
    require('shooter.analytics').show_project()
  end, { desc = 'Show project shot analytics' })

  vim.api.nvim_create_user_command('ShooterSoundTest', function()
    require('shooter.sound').test()
  end, { desc = 'Test shot sound' })

  -- History commands
  vim.api.nvim_create_user_command('ShooterMigrateHistory', function()
    local history = require('shooter.history')
    local migrated, skipped = history.migrate_history_files()
    vim.notify(string.format('History migration: %d migrated, %d skipped', migrated, skipped))
  end, { desc = 'Migrate history files to new timestamp format' })

  vim.api.nvim_create_user_command('ShooterOpenHistory', function()
    local history = require('shooter.history')
    local utils = require('shooter.utils')
    local user, repo = history.get_git_remote_info()
    if not user or not repo then
      local cwd = utils.cwd()
      user, repo = 'local', utils.get_basename(cwd)
    end
    local history_dir = string.format('%s/%s/%s', history.get_history_base_dir(), user, repo)
    vim.fn.mkdir(history_dir, 'p')
    vim.cmd('Oil ' .. history_dir)
  end, { desc = 'Open history directory in Oil' })

  -- Load send/queue commands from submodule
  require('shooter.commands.send').setup()
end

return M
