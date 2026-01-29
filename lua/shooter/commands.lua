-- Command registration for shooter.nvim
-- Organized by namespace: Shotfile, Shot, Tmux, Subproject, Tool, Cfg, Analytics, Help

local M = {}

-- Create command with optional alias for backward compatibility
local function create_cmd(name, fn, opts, alias)
  vim.api.nvim_create_user_command(name, fn, opts)
  if alias then
    vim.api.nvim_create_user_command(alias, fn, opts)
  end
end

-- Setup Shotfile namespace commands (f prefix in keymaps)
local function setup_shotfile_commands()
  local files = require('shooter.core.files')
  local movement = require('shooter.core.movement')
  local project_mod = require('shooter.core.project')

  -- ShooterShotfileNew (alias: ShooterCreate)
  create_cmd('ShooterShotfileNew', function(opts)
    local function create_with_title_and_project(title, project)
      if not title or title == '' then return end
      local path = files.create_file(title, '', '', project)
      if path then
        vim.cmd('edit! ' .. vim.fn.fnameescape(path))
        vim.schedule(function()
          vim.api.nvim_win_set_cursor(0, {4, 0})
          vim.cmd('startinsert')
        end)
      end
    end

    local function prompt_for_title(project)
      if opts.args ~= '' then
        create_with_title_and_project(opts.args, project)
      else
        vim.ui.input({ prompt = 'Feature title: ' }, function(title)
          create_with_title_and_project(title, project)
        end)
      end
    end

    local detected_project = project_mod.detect_from_cwd()
    if detected_project then
      prompt_for_title(detected_project)
    elseif project_mod.has_projects() then
      project_mod.pick_project(function(selected_project)
        prompt_for_title(selected_project)
      end, { include_root = true, title = 'Create in Project' })
    else
      prompt_for_title(nil)
    end
  end, { nargs = '?', desc = 'Create new shotfile' }, 'ShooterCreate')

  -- ShooterShotfileNewInRepo (alias: ShooterCreateInRepo)
  create_cmd('ShooterShotfileNewInRepo', function()
    require('shooter.core.repos').create_in_repo_picker()
  end, { desc = 'Create shotfile in any configured repo' }, 'ShooterCreateInRepo')

  -- ShooterShotfilePicker (alias: ShooterList)
  create_cmd('ShooterShotfilePicker', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_files({ include_all_projects = true })
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (current repo)' }, 'ShooterList')

  -- ShooterShotfilePickerAll (alias: ShooterListAll)
  create_cmd('ShooterShotfilePickerAll', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_repos_files()
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (all repos)' }, 'ShooterListAll')

  -- ShooterShotfileLast (alias: ShooterLast)
  create_cmd('ShooterShotfileLast', function()
    local last_file = files.get_last_edited_file()
    if last_file then vim.cmd('edit ' .. vim.fn.fnameescape(last_file)) end
  end, { desc = 'Open last edited shotfile' }, 'ShooterLast')

  -- ShooterShotfileRename
  create_cmd('ShooterShotfileRename', function()
    require('shooter.core.rename').rename_current_file()
  end, { desc = 'Rename current shotfile' })

  -- ShooterShotfileDelete
  create_cmd('ShooterShotfileDelete', function()
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == '' then
      vim.notify('No file to delete', vim.log.levels.WARN)
      return
    end
    vim.ui.input({ prompt = 'Delete ' .. vim.fn.fnamemodify(bufname, ':t') .. '? (y/n): ' }, function(confirm)
      if confirm == 'y' then
        vim.cmd('bdelete!')
        vim.fn.delete(bufname)
        vim.notify('Deleted: ' .. vim.fn.fnamemodify(bufname, ':t'), vim.log.levels.INFO)
      end
    end)
  end, { desc = 'Delete current shotfile' })

  -- ShooterShotfileOpenPrompts (alias: ShooterOpenPrompts)
  create_cmd('ShooterShotfileOpenPrompts', function()
    local config = require('shooter.config')
    local prompts_dir = config.get('paths.prompts_dir')
    vim.fn.mkdir(prompts_dir, 'p')
    vim.cmd('Oil ' .. prompts_dir)
  end, { desc = 'Open Oil in prompts folder' }, 'ShooterOpenPrompts')

  -- ShooterOpenPlans - Open plans folder in Oil
  create_cmd('ShooterOpenPlans', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if git_root then
      local plans_dir = git_root .. '/plans'
      vim.fn.mkdir(plans_dir, 'p')
      vim.cmd('Oil ' .. plans_dir)
    else
      vim.notify('Not in a git repository', vim.log.levels.WARN)
    end
  end, { desc = 'Open plans folder in Oil' })

  -- ShooterOpenShooterConfig - Open .shooter.nvim folder in Oil
  create_cmd('ShooterOpenShooterConfig', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if git_root then
      local shooter_dir = git_root .. '/.shooter.nvim'
      vim.fn.mkdir(shooter_dir, 'p')
      vim.cmd('Oil ' .. shooter_dir)
    else
      vim.notify('Not in a git repository', vim.log.levels.WARN)
    end
  end, { desc = 'Open .shooter.nvim folder in Oil' })

  -- Move commands
  create_cmd('ShooterShotfileMoveArchive', movement.move_to_archive, { desc = 'Move to archive' }, 'ShooterArchive')
  create_cmd('ShooterShotfileMoveBacklog', movement.move_to_backlog, { desc = 'Move to backlog' }, 'ShooterBacklog')
  create_cmd('ShooterShotfileMoveDone', movement.move_to_done, { desc = 'Move to done' }, 'ShooterDone')
  create_cmd('ShooterShotfileMovePrompts', movement.move_to_prompts, { desc = 'Move to prompts' }, 'ShooterPrompts')
  create_cmd('ShooterShotfileMoveReqs', movement.move_to_reqs, { desc = 'Move to reqs' }, 'ShooterReqs')
  create_cmd('ShooterShotfileMoveTest', movement.move_to_test, { desc = 'Move to test' }, 'ShooterTest')
  create_cmd('ShooterShotfileMoveWait', movement.move_to_wait, { desc = 'Move to wait' }, 'ShooterWait')
  create_cmd('ShooterShotfileMoveGitRoot', movement.move_to_git_root, { desc = 'Move to git root' }, 'ShooterGitRoot')

  -- ShooterShotfileMovePicker (alias: ShooterMovePicker)
  create_cmd('ShooterShotfileMovePicker', function()
    require('shooter.core.move_picker').open_picker()
  end, { desc = 'Move file via fuzzy picker' }, 'ShooterMovePicker')

  -- ShooterShotfileCfg = ShooterCfgShotfile (bidirectional alias handled in Cfg)
end

-- Setup Shot namespace commands (s prefix in keymaps)
local function setup_shot_commands()
  local shot_actions = require('shooter.core.shot_actions')
  local tmux = require('shooter.tmux')

  -- ShooterShotNew (alias: ShooterNewShot)
  create_cmd('ShooterShotNew', shot_actions.create_new_shot, { desc = 'Create new shot' }, 'ShooterNewShot')

  -- ShooterShotNewWhisper (alias: ShooterNewShotWhisper)
  create_cmd('ShooterShotNewWhisper', shot_actions.create_new_shot_with_whisper,
    { desc = 'New shot + whisper' }, 'ShooterNewShotWhisper')

  -- ShooterShotDelete (alias: ShooterDeleteLastShot)
  create_cmd('ShooterShotDelete', shot_actions.delete_last_shot,
    { desc = 'Delete last shot' }, 'ShooterDeleteLastShot')

  -- ShooterShotToggle (alias: ShooterToggleDone)
  create_cmd('ShooterShotToggle', shot_actions.toggle_shot_done,
    { desc = 'Toggle shot done' }, 'ShooterToggleDone')

  -- ShooterShotDeleteCursor (alias: ShooterDeleteShotUnderCursor)
  create_cmd('ShooterShotDeleteCursor', function()
    require('shooter.core.shot_delete').delete_shot_under_cursor()
  end, { desc = 'Delete shot under cursor' }, 'ShooterDeleteShotUnderCursor')

  -- ShooterShotMove (alias: ShooterMoveShot)
  create_cmd('ShooterShotMove', function()
    require('shooter.core.shot_move').move_shot()
  end, { desc = 'Move shot to another file' }, 'ShooterMoveShot')

  -- ShooterShotYank
  create_cmd('ShooterShotYank', shot_actions.yank_shot, { desc = 'Yank shot to clipboard' })

  -- ShooterShotExtractBlock (alias: ShooterShotExtract for backward compat)
  create_cmd('ShooterShotExtractBlock', shot_actions.extract_subtask,
    { desc = 'Extract ### subtask block to new shot' }, 'ShooterShotExtract')

  -- ShooterShotExtractLine
  create_cmd('ShooterShotExtractLine', shot_actions.extract_line,
    { desc = 'Extract current line to new shot' })

  -- ShooterShotMunition (alias: ShooterMunition)
  create_cmd('ShooterShotMunition', function()
    require('shooter.inbox.picker').show_file_picker()
  end, { desc = 'Import tasks from inbox' }, 'ShooterMunition')

  -- ShooterShotPicker (alias: ShooterOpenShots)
  create_cmd('ShooterShotPicker', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then picker:find() end
  end, { desc = 'Open shots picker' }, 'ShooterOpenShots')

  -- Navigation commands
  create_cmd('ShooterShotNavNext', shot_actions.goto_next_open_shot,
    { desc = 'Next open shot' }, 'ShooterNextShot')
  create_cmd('ShooterShotNavPrev', shot_actions.goto_prev_open_shot,
    { desc = 'Previous open shot' }, 'ShooterPrevShot')
  create_cmd('ShooterShotNavNextSent', shot_actions.goto_next_sent_shot,
    { desc = 'Next sent shot' }, 'ShooterNextSent')
  create_cmd('ShooterShotNavPrevSent', shot_actions.goto_prev_sent_shot,
    { desc = 'Previous sent shot' }, 'ShooterPrevSent')
  create_cmd('ShooterShotNavLatest', shot_actions.goto_latest_sent_shot,
    { desc = 'Latest sent shot' }, 'ShooterLatestSent')
  create_cmd('ShooterShotNavUndo', shot_actions.undo_latest_sent_shot,
    { desc = 'Undo latest sent' }, 'ShooterUndoLatestSent')

  -- Send commands (1-9)
  for i = 1, 9 do
    create_cmd('ShooterShotSend' .. i, function()
      tmux.send_current_shot(i)
    end, { desc = 'Send shot to pane ' .. i }, 'ShooterSend' .. i)

    create_cmd('ShooterShotSendAll' .. i, function()
      tmux.send_all_shots(i)
    end, { desc = 'Send all shots to pane ' .. i }, 'ShooterSendAll' .. i)

    create_cmd('ShooterShotSendVisual' .. i, function(opts)
      tmux.send_visual_selection(i, opts.line1, opts.line2)
    end, { range = true, desc = 'Send selection to pane ' .. i }, 'ShooterSendVisual' .. i)

    create_cmd('ShooterShotResend' .. i, function()
      tmux.resend_latest_shot(i)
    end, { desc = 'Resend to pane ' .. i }, 'ShooterResend' .. i)
  end

  -- Queue commands (1-4)
  local queue = require('shooter.queue')
  for i = 1, 4 do
    create_cmd('ShooterShotQueue' .. i, function()
      queue.add_to_queue(nil, i)
    end, { desc = 'Queue for pane ' .. i }, 'ShooterQueueAdd' .. i)
  end

  create_cmd('ShooterShotQueueView', function()
    require('shooter.queue.picker').show_queue()
  end, { desc = 'View queue' }, 'ShooterQueueView')

  create_cmd('ShooterShotQueueClear', function()
    queue.clear_queue()
  end, { desc = 'Clear queue' }, 'ShooterQueueClear')

  -- ShooterShotsRenumber - Renumber all shots sequentially
  create_cmd('ShooterShotsRenumber', function()
    local renumber = require('shooter.core.renumber')
    local count = renumber.renumber_shots()
    if count > 0 then
      vim.notify(string.format('Renumbered %d shots', count), vim.log.levels.INFO)
    end
  end, { desc = 'Renumber shots sequentially' })

  -- ShooterShotCfg = ShooterCfgShot (bidirectional alias handled in Cfg)
end

-- Setup Tmux namespace commands (t prefix in keymaps)
local function setup_tmux_commands()
  local wrapper = require('shooter.tmux.wrapper')

  create_cmd('ShooterTmuxZoom', wrapper.zoom_toggle, { desc = 'Tmux: zoom toggle' })
  create_cmd('ShooterTmuxEdit', wrapper.edit_in_vim, { desc = 'Tmux: edit in vim' })
  create_cmd('ShooterTmuxGit', wrapper.git_status_toggle, { desc = 'Tmux: git status' })
  create_cmd('ShooterTmuxLight', wrapper.lightswitch, { desc = 'Tmux: light/dark' })
  create_cmd('ShooterTmuxKillOthers', wrapper.kill_other_panes, { desc = 'Tmux: kill others' })
  create_cmd('ShooterTmuxReload', wrapper.reload_session, { desc = 'Tmux: reload' })
  create_cmd('ShooterTmuxDelete', wrapper.delete_session, { desc = 'Tmux: delete session' })
  create_cmd('ShooterTmuxSmug', wrapper.smug_load, { desc = 'Tmux: smug load' })
  create_cmd('ShooterTmuxYank', wrapper.yank_to_vim, { desc = 'Tmux: yank to vim' })
  create_cmd('ShooterTmuxChoose', wrapper.choose_session, { desc = 'Tmux: choose session' })
  create_cmd('ShooterTmuxSwitch', wrapper.switch_last, { desc = 'Tmux: switch last' })

  -- ShooterTmuxWatch (alias: ShooterWatch)
  create_cmd('ShooterTmuxWatch', function()
    require('shooter.tmux.watch').open_watch_pane()
  end, { desc = 'Tmux: watch pane' }, 'ShooterWatch')

  -- Pane toggle (0-9)
  for i = 0, 9 do
    create_cmd('ShooterTmuxPaneToggle' .. i, function()
      require('shooter.tmux.panes').toggle(i)
    end, { desc = 'Toggle pane ' .. i }, 'ShooterPaneToggle' .. i)
  end
end

-- Setup Subproject namespace commands (p prefix in keymaps)
local function setup_subproject_commands()
  local project_mod = require('shooter.core.project')
  local files = require('shooter.core.files')

  -- ShooterSubprojectNew
  create_cmd('ShooterSubprojectNew', function(opts)
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end

    local function create_project(name)
      if not name or name == '' then return end
      local project_path = git_root .. '/projects/' .. name
      if vim.fn.isdirectory(project_path) == 1 then
        vim.notify('Project already exists: ' .. name, vim.log.levels.WARN)
        return
      end
      -- Create standard folder structure
      local folders = { 'plans/prompts', 'plans/prompts/archive', 'plans/prompts/backlog',
        'plans/prompts/done', 'plans/prompts/reqs', 'plans/prompts/test', 'plans/prompts/wait' }
      for _, folder in ipairs(folders) do
        vim.fn.mkdir(project_path .. '/' .. folder, 'p')
      end
      vim.notify('Created project: ' .. name, vim.log.levels.INFO)
      vim.cmd('Oil ' .. project_path)
    end

    if opts.args ~= '' then
      create_project(opts.args)
    else
      vim.ui.input({ prompt = 'Project name: ' }, create_project)
    end
  end, { nargs = '?', desc = 'Create new subproject' })

  -- ShooterSubprojectList
  create_cmd('ShooterSubprojectList', function()
    local projects = project_mod.list_projects()
    if #projects == 0 then
      vim.notify('No projects found', vim.log.levels.INFO)
      return
    end
    project_mod.pick_project(function(project)
      if project then
        local git_root = files.get_git_root()
        vim.cmd('Oil ' .. git_root .. '/projects/' .. project)
      end
    end)
  end, { desc = 'List and select subproject' })

  -- ShooterSubprojectEnsure
  create_cmd('ShooterSubprojectEnsure', function()
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local project = project_mod.detect_from_cwd()
    local base = project and (git_root .. '/projects/' .. project) or git_root
    local folders = { 'plans/prompts', 'plans/prompts/archive', 'plans/prompts/backlog',
      'plans/prompts/done', 'plans/prompts/reqs', 'plans/prompts/test', 'plans/prompts/wait' }
    for _, folder in ipairs(folders) do
      vim.fn.mkdir(base .. '/' .. folder, 'p')
    end
    vim.notify('Standard folders ensured', vim.log.levels.INFO)
  end, { desc = 'Ensure standard folders exist' })
end

-- Setup Tool namespace commands (l prefix in keymaps)
local function setup_tool_commands()
  -- ShooterToolToken (alias: ShooterToolTokenCounter)
  create_cmd('ShooterToolToken', function()
    require('shooter.tools.token_counter').show_token_count()
  end, { desc = 'Count tokens' }, 'ShooterToolTokenCounter')

  -- ShooterToolObsidian (alias: ShooterOpenObsidian)
  create_cmd('ShooterToolObsidian', function()
    require('shooter.tools.obsidian').open_in_obsidian()
  end, { desc = 'Open in Obsidian' }, 'ShooterOpenObsidian')

  -- ShooterToolImages (alias: ShooterImages)
  create_cmd('ShooterToolImages', function()
    require('shooter.images').insert_images()
  end, { desc = 'Insert images' }, 'ShooterImages')

  -- ShooterToolPrd (alias: ShooterPrdList)
  create_cmd('ShooterToolPrd', function()
    require('shooter.prd').list()
  end, { desc = 'PRD list' }, 'ShooterPrdList')

  -- ShooterToolGreenkeep (alias: ShooterGreenkeep)
  create_cmd('ShooterToolGreenkeep', function()
    require('shooter.core.greenkeep').run()
  end, { desc = 'Convert old date formats' }, 'ShooterGreenkeep')

  -- ShooterToolSoundTest (alias: ShooterSoundTest)
  create_cmd('ShooterToolSoundTest', function()
    require('shooter.sound').test()
  end, { desc = 'Test sound' }, 'ShooterSoundTest')

  -- ShooterToolClipboardPaste - Paste clipboard image
  create_cmd('ShooterToolClipboardPaste', function()
    require('shooter.tools.clipboard_image').paste_image_normal()
  end, { desc = 'Paste clipboard image' })

  -- ShooterToolClipboardCheck - Check if clipboard has image
  create_cmd('ShooterToolClipboardCheck', function()
    require('shooter.tools.clipboard_image').check()
  end, { desc = 'Check clipboard for image' })

  -- ShooterToolClipboardImages - Open images directory
  create_cmd('ShooterToolClipboardImages', function()
    require('shooter.tools.clipboard_image').open_images_dir()
  end, { desc = 'Open clipboard images folder' })
end

-- Setup Cfg namespace commands (c prefix in keymaps)
local function setup_cfg_commands()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  -- ShooterCfgGlobal (alias: ShooterEditGlobalContext)
  create_cmd('ShooterCfgGlobal', function()
    local global_path = utils.expand_path(config.get('paths.global_context'))
    vim.fn.mkdir(vim.fn.fnamemodify(global_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(global_path))
  end, { desc = 'Edit global context' }, 'ShooterEditGlobalContext')

  -- ShooterCfgProject (alias: ShooterEditProjectContext)
  create_cmd('ShooterCfgProject', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local project_path = git_root .. '/' .. config.get('paths.project_context')
    vim.fn.mkdir(vim.fn.fnamemodify(project_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(project_path))
  end, { desc = 'Edit project context' }, 'ShooterEditProjectContext')

  -- ShooterCfgPlugin (alias: ShooterEditConfig)
  create_cmd('ShooterCfgPlugin', function()
    local config_path = utils.find_config_file()
    if not config_path then
      vim.notify('Shooter config file not found', vim.log.levels.WARN)
      return
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
  end, { desc = 'Edit plugin config' }, 'ShooterEditConfig')

  -- ShooterCfgShot = ShooterShotCfg (shot picker config - vimMode)
  create_cmd('ShooterCfgShot', function()
    local session = require('shooter.session')
    local current = session.get_current_session()
    local modes = { 'normal', 'insert' }
    local current_mode = current.vimMode and current.vimMode.shotPicker or 'insert'
    local next_idx = 1
    for i, m in ipairs(modes) do
      if m == current_mode then next_idx = (i % #modes) + 1 end
    end
    session.set_vim_mode('shotPicker', modes[next_idx])
    vim.notify('Shot picker mode: ' .. modes[next_idx], vim.log.levels.INFO)
  end, { desc = 'Toggle shot picker vim mode' })
  vim.api.nvim_create_user_command('ShooterShotCfg', function() vim.cmd('ShooterCfgShot') end, { desc = 'Toggle shot picker vim mode' })

  -- ShooterCfgShotfile = ShooterShotfileCfg (shotfile picker config - sessions)
  create_cmd('ShooterCfgShotfile', function()
    local session = require('shooter.session')
    vim.cmd('tabedit ' .. vim.fn.fnameescape(session.get_session_file_path()))
  end, { desc = 'Edit shotfile picker session config' })
  vim.api.nvim_create_user_command('ShooterShotfileCfg', function() vim.cmd('ShooterCfgShotfile') end, { desc = 'Edit shotfile picker session config' })
end

-- Setup Analytics namespace commands (a prefix in keymaps)
local function setup_analytics_commands()
  -- ShooterAnalyticsProject (alias: ShooterAnalyticsProject - same name)
  create_cmd('ShooterAnalyticsProject', function()
    require('shooter.analytics').show_project()
  end, { desc = 'Project analytics' })

  -- ShooterAnalyticsGlobal
  create_cmd('ShooterAnalyticsGlobal', function()
    require('shooter.analytics').show_global()
  end, { desc = 'Global analytics' })
end

-- Setup Help namespace commands (h prefix in keymaps)
local function setup_help_commands()
  -- ShooterHelp
  create_cmd('ShooterHelp', function()
    require('shooter.help').show()
  end, { desc = 'Show help' })

  -- ShooterHealth (alias: stays same)
  create_cmd('ShooterHealth', function()
    vim.cmd('checkhealth shooter')
  end, { desc = 'Health check' })

  -- ShooterHelpDashboard (alias: ShooterDashboard)
  create_cmd('ShooterHelpDashboard', function()
    require('shooter.dashboard').open()
  end, { desc = 'Open dashboard' }, 'ShooterDashboard')

  -- ShooterCheatsheet
  create_cmd('ShooterCheatsheet', function()
    require('shooter.cheatsheet').show()
  end, { desc = 'Show cheatsheet' })
end

-- Setup Nav namespace commands (z prefix in keymaps)
local function setup_nav_commands()
  local files = require('shooter.core.files')

  -- Helper to get last N edited files in repo
  local function get_last_edited_files(git_root, count)
    local cmd = string.format(
      'find "%s" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" ' ..
      '-not -path "*/__pycache__/*" -not -name "*.pyc" -not -name ".DS_Store" ' ..
      '-exec ls -t {} + 2>/dev/null | head -%d',
      git_root, count
    )
    local handle = io.popen(cmd)
    if not handle then return {} end
    local results = {}
    for line in handle:lines() do
      if line ~= '' then table.insert(results, line) end
    end
    handle:close()
    return results
  end

  -- ShooterNavLastEditedFile - opens most recently modified file in repo
  create_cmd('ShooterNavLastEditedFile', function()
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local results = get_last_edited_files(git_root, 1)
    if #results > 0 then
      vim.cmd('edit ' .. vim.fn.fnameescape(results[1]))
    else
      vim.notify('No files found in repository', vim.log.levels.INFO)
    end
  end, { desc = 'Open last edited file in repo' })

  -- Alias for backward compatibility
  vim.api.nvim_create_user_command('ShooterRepoOpenLastEditedFile', function()
    vim.cmd('ShooterNavLastEditedFile')
  end, { desc = 'Open last edited file in repo' })

  -- ShooterNavLastEditedFiles - telescope picker for last N edited files
  create_cmd('ShooterNavLastEditedFiles', function(opts)
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local count = tonumber(opts.args) or 10
    local results = get_last_edited_files(git_root, count)
    if #results == 0 then
      vim.notify('No files found in repository', vim.log.levels.INFO)
      return
    end

    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers.new({}, {
      prompt_title = 'Last ' .. count .. ' Edited Files',
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          local short = entry:gsub('^' .. vim.pesc(git_root) .. '/', '')
          return { value = entry, display = short, ordinal = short }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then vim.cmd('edit ' .. vim.fn.fnameescape(selection.value)) end
        end)
        return true
      end,
    }):find()
  end, { nargs = '?', desc = 'Telescope picker for last N edited files' })
end

-- Setup utility commands (not in main namespaces)
local function setup_utility_commands()
  -- Filter clearing
  create_cmd('ShooterClearFilter', function()
    local filter_state = require('shooter.filter_state')
    filter_state.clear_all_filters()
    vim.notify('Filters cleared', vim.log.levels.INFO)
  end, { desc = 'Clear all filters' })

  -- Inbox (at git root)
  create_cmd('ShooterInbox', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local inbox_path = git_root .. '/INBOX.md'
    if vim.fn.filereadable(inbox_path) ~= 1 then
      local file = io.open(inbox_path, 'w')
      if file then file:write('# Inbox\n\n'); file:close() end
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(inbox_path))
  end, { desc = 'Open INBOX.md at git root' })

end

-- Setup all vim commands
function M.setup()
  setup_shotfile_commands()
  setup_shot_commands()
  setup_tmux_commands()
  setup_subproject_commands()
  setup_tool_commands()
  setup_cfg_commands()
  setup_analytics_commands()
  setup_help_commands()
  setup_nav_commands()
  setup_utility_commands()
end

return M
