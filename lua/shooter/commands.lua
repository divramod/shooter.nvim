-- Command registration for shooter.nvim
-- Organized by namespace: Shotfile, Shot, Tmux, Subproject, Tool, Cfg, Analytics, Help

local M = {}

-- Guard: wraps a function so it only runs in shotfiles (.shooter/ai/shotfiles)
-- Returns the original function wrapped with an is_shooter_file() check
local function require_shotfile(fn)
  return function(opts)
    local files = require('shooter.core.files')
    if not files.is_shooter_file() then
      vim.notify('This command only works in shotfiles (.shooter/ai/shotfiles)', vim.log.levels.WARN)
      return
    end
    fn(opts)
  end
end

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

  -- ShoShotfileNew (alias: ShoCreate)
  create_cmd('ShoShotfileNew', function(opts)
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
  end, { nargs = '?', desc = 'Create new shotfile' }, 'ShoCreate')

  -- ShoShotfileNewInRepo (alias: ShoCreateInRepo)
  create_cmd('ShoShotfileNewInRepo', function()
    require('shooter.core.repos').create_in_repo_picker()
  end, { desc = 'Create shotfile in any configured repo' }, 'ShoCreateInRepo')

  -- ShoShotfilePicker (alias: ShoList)
  create_cmd('ShoShotfilePicker', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_files({ include_all_projects = true })
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (current repo)' }, 'ShoList')

  -- ShoShotfilePickerAll (alias: ShoListAll)
  create_cmd('ShoShotfilePickerAll', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_repos_files()
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (all repos)' }, 'ShoListAll')

  -- ShoShotfileLast (alias: ShoLast)
  create_cmd('ShoShotfileLast', function()
    local last_file = files.get_last_edited_file()
    if last_file then vim.cmd('edit ' .. vim.fn.fnameescape(last_file)) end
  end, { desc = 'Open last edited shotfile' }, 'ShoLast')

  -- ShoShotfileRename
  create_cmd('ShoShotfileRename', function()
    require('shooter.core.rename').rename_current_file()
  end, { desc = 'Rename current shotfile' })

  -- ShoShotfileDelete
  create_cmd('ShoShotfileDelete', function()
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

  -- ShoShotfileOpenPrompts (alias: ShoOpenPrompts)
  create_cmd('ShoShotfileOpenPrompts', function()
    local config = require('shooter.config')
    local prompts_dir = config.get('paths.prompts_dir')
    vim.fn.mkdir(prompts_dir, 'p')
    -- Auto-create missing theme shotfiles from .shooter/themes.json
    local created = files.ensure_theme_shotfiles()
    if created > 0 then
      vim.notify(string.format('Created %d theme shotfiles', created), vim.log.levels.INFO)
    end
    vim.cmd('Oil ' .. prompts_dir)
  end, { desc = 'Open Oil in prompts folder' }, 'ShoOpenPrompts')

  -- ShoOpenPlans - Open plans folder in Oil
  create_cmd('ShoOpenPlans', function()
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

  -- ShoOpenShoConfig - Open .shooter/config/nvim folder in Oil
  create_cmd('ShoOpenShoConfig', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if git_root then
      local shooter_dir = git_root .. '/.shooter/config/nvim'
      vim.fn.mkdir(shooter_dir, 'p')
      vim.cmd('Oil ' .. shooter_dir)
    else
      vim.notify('Not in a git repository', vim.log.levels.WARN)
    end
  end, { desc = 'Open .shooter/config/nvim folder in Oil' })

  -- Move commands
  create_cmd('ShoShotfileMoveArchive', movement.move_to_archive, { desc = 'Move to archive' }, 'ShoArchive')
  create_cmd('ShoShotfileMoveBacklog', movement.move_to_backlog, { desc = 'Move to backlog' }, 'ShoBacklog')
  create_cmd('ShoShotfileMoveDone', movement.move_to_done, { desc = 'Move to done' }, 'ShoDone')
  create_cmd('ShoShotfileMovePrompts', movement.move_to_prompts, { desc = 'Move to prompts' }, 'ShoPrompts')
  create_cmd('ShoShotfileMoveReqs', movement.move_to_reqs, { desc = 'Move to reqs' }, 'ShoReqs')
  create_cmd('ShoShotfileMoveTest', movement.move_to_test, { desc = 'Move to test' }, 'ShoTest')
  create_cmd('ShoShotfileMoveWait', movement.move_to_wait, { desc = 'Move to wait' }, 'ShoWait')
  create_cmd('ShoShotfileMoveGitRoot', movement.move_to_git_root, { desc = 'Move to git root' }, 'ShoGitRoot')

  -- ShoShotfileMovePicker (alias: ShoMovePicker)
  create_cmd('ShoShotfileMovePicker', function()
    require('shooter.core.move_picker').open_picker()
  end, { desc = 'Move file via fuzzy picker' }, 'ShoMovePicker')

  -- ShoShotfileCfg = ShoCfgShotfile (bidirectional alias handled in Cfg)
end

-- Setup Shot namespace commands (s prefix in keymaps)
local function setup_shot_commands()
  local shot_actions = require('shooter.core.shot_actions')
  local tmux = require('shooter.tmux')

  -- ShoShotNew (alias: ShoNewShot)
  create_cmd('ShoShotNew', require_shotfile(shot_actions.create_new_shot), { desc = 'Create new shot' }, 'ShoNewShot')

  -- ShoShotNewWhisper (alias: ShoNewShotWhisper)
  create_cmd('ShoShotNewWhisper', require_shotfile(shot_actions.create_new_shot_with_whisper),
    { desc = 'New shot + whisper' }, 'ShoNewShotWhisper')

  -- ShoShotDelete (alias: ShoDeleteLastShot)
  create_cmd('ShoShotDelete', require_shotfile(shot_actions.delete_last_shot),
    { desc = 'Delete last shot' }, 'ShoDeleteLastShot')

  -- ShoShotToggle (alias: ShoToggleDone)
  create_cmd('ShoShotToggle', require_shotfile(shot_actions.toggle_shot_done),
    { desc = 'Toggle shot done' }, 'ShoToggleDone')

  -- ShoShotDeleteCursor (alias: ShoDeleteShotUnderCursor)
  create_cmd('ShoShotDeleteCursor', require_shotfile(function()
    require('shooter.core.shot_delete').delete_shot_under_cursor()
  end), { desc = 'Delete shot under cursor' }, 'ShoDeleteShotUnderCursor')

  -- ShoShotMove (alias: ShoMoveShot)
  create_cmd('ShoShotMove', require_shotfile(function()
    require('shooter.core.shot_move').move_shot()
  end), { desc = 'Move shot to another file' }, 'ShoMoveShot')

  -- ShoShotYank
  create_cmd('ShoShotYank', require_shotfile(shot_actions.yank_shot), { desc = 'Yank shot to clipboard' })

  -- ShoShotViewResponse
  create_cmd('ShoShotViewResponse', require_shotfile(function()
    require('shooter.tools.response_viewer').view_response()
  end), { desc = 'View response for shot' })

  -- ShoShotExtractBlock (alias: ShoShotExtract for backward compat)
  create_cmd('ShoShotExtractBlock', require_shotfile(shot_actions.extract_subtask),
    { desc = 'Extract ### subtask block to new shot' }, 'ShoShotExtract')

  -- ShoShotExtractLine
  create_cmd('ShoShotExtractLine', require_shotfile(shot_actions.extract_line),
    { desc = 'Extract current line to new shot' })

  -- ShoShotMunition (alias: ShoMunition)
  create_cmd('ShoShotMunition', require_shotfile(function()
    require('shooter.inbox.picker').show_file_picker()
  end), { desc = 'Import tasks from inbox' }, 'ShoMunition')

  -- ShoShotPicker (alias: ShoOpenShots)
  create_cmd('ShoShotPicker', require_shotfile(function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then picker:find() end
  end), { desc = 'Open shots picker' }, 'ShoOpenShots')

  -- Navigation commands
  create_cmd('ShoShotNavNext', require_shotfile(shot_actions.goto_next_open_shot),
    { desc = 'Next open shot' }, 'ShoNextShot')
  create_cmd('ShoShotNavPrev', require_shotfile(shot_actions.goto_prev_open_shot),
    { desc = 'Previous open shot' }, 'ShoPrevShot')
  create_cmd('ShoShotNavNextSent', require_shotfile(shot_actions.goto_next_sent_shot),
    { desc = 'Next sent shot' }, 'ShoNextSent')
  create_cmd('ShoShotNavPrevSent', require_shotfile(shot_actions.goto_prev_sent_shot),
    { desc = 'Previous sent shot' }, 'ShoPrevSent')
  create_cmd('ShoShotNavLatest', require_shotfile(shot_actions.goto_latest_sent_shot),
    { desc = 'Latest sent shot' }, 'ShoLatestSent')
  create_cmd('ShoShotNavUndo', require_shotfile(shot_actions.undo_latest_sent_shot),
    { desc = 'Undo latest sent' }, 'ShoUndoLatestSent')

  -- Send commands with optional pane argument (defaults to 1)
  create_cmd('ShoShotSend', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_current_shot(pane)
  end), { nargs = '?', desc = 'Send shot to pane [1-9]' }, 'ShoSend')

  create_cmd('ShoShotSendAll', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_all_shots(pane)
  end), { nargs = '?', desc = 'Send all shots to pane [1-9]' }, 'ShoSendAll')

  create_cmd('ShoShotSendVisual', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_visual_selection(pane, opts.line1, opts.line2)
  end), { range = true, nargs = '?', desc = 'Send selection to pane [1-9]' }, 'ShoSendVisual')

  create_cmd('ShoShotResend', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.resend_latest_shot(pane)
  end), { nargs = '?', desc = 'Resend to pane [1-9]' }, 'ShoResend')

  -- Queue commands (1-4)
  local queue = require('shooter.queue')
  for i = 1, 4 do
    create_cmd('ShoShotQueue' .. i, require_shotfile(function()
      queue.add_to_queue(nil, i)
    end), { desc = 'Queue for pane ' .. i }, 'ShoQueueAdd' .. i)
  end

  create_cmd('ShoShotQueueView', require_shotfile(function()
    require('shooter.queue.picker').show_queue()
  end), { desc = 'View queue' }, 'ShoQueueView')

  create_cmd('ShoShotQueueClear', require_shotfile(function()
    queue.clear_queue()
  end), { desc = 'Clear queue' }, 'ShoQueueClear')

  -- ShoFileStats - Show stats for current shotfile
  create_cmd('ShoFileStats', require_shotfile(shot_actions.file_stats), { desc = 'Shotfile stats (total/open/closed)' })

  -- ShoFileToggleFirstShotOfDayColoring - Toggle day marker highlighting
  create_cmd('ShoFileToggleFirstShotOfDayColoring', require_shotfile(function()
    require('shooter.syntax').toggle_day_marker()
  end), { desc = 'Toggle first-shot-of-day coloring' })

  -- ShoShotCreateFromClaude - Cut text from Claude editor and create shot in right pane
  create_cmd('ShoShotCreateFromClaude', shot_actions.create_shot_from_claude,
    { desc = 'Cut Claude text, create shot in right pane' })

  -- ShoShotsRenumber - Renumber all shots sequentially
  create_cmd('ShoShotsRenumber', require_shotfile(function()
    local renumber = require('shooter.core.renumber')
    local count = renumber.renumber_shots()
    if count > 0 then
      vim.notify(string.format('Renumbered %d shots', count), vim.log.levels.INFO)
    end
  end), { desc = 'Renumber shots sequentially' })

  -- ShoShotCfg = ShoCfgShot (bidirectional alias handled in Cfg)
end

-- Setup Tmux namespace commands (t prefix in keymaps)
local function setup_tmux_commands()
  local wrapper = require('shooter.tmux.wrapper')

  create_cmd('ShoTmuxZoom', wrapper.zoom_toggle, { desc = 'Tmux: zoom toggle' })
  create_cmd('ShoTmuxEdit', wrapper.edit_in_vim, { desc = 'Tmux: edit in vim' })
  create_cmd('ShoTmuxGit', wrapper.git_status_toggle, { desc = 'Tmux: git status' })
  create_cmd('ShoTmuxLight', wrapper.lightswitch, { desc = 'Tmux: light/dark' })
  create_cmd('ShoTmuxKillOthers', wrapper.kill_other_panes, { desc = 'Tmux: kill others' })
  create_cmd('ShoTmuxReload', wrapper.reload_session, { desc = 'Tmux: reload' })
  create_cmd('ShoTmuxDelete', wrapper.delete_session, { desc = 'Tmux: delete session' })
  create_cmd('ShoTmuxSmug', wrapper.smug_load, { desc = 'Tmux: smug load' })
  create_cmd('ShoTmuxYank', wrapper.yank_to_vim, { desc = 'Tmux: yank to vim' })
  create_cmd('ShoTmuxChoose', wrapper.choose_session, { desc = 'Tmux: choose session' })
  create_cmd('ShoTmuxSwitch', wrapper.switch_last, { desc = 'Tmux: switch last' })

  -- ShoTmuxWatch (alias: ShoWatch)
  create_cmd('ShoTmuxWatch', function()
    require('shooter.tmux.watch').open_watch_pane()
  end, { desc = 'Tmux: watch pane' }, 'ShoWatch')

  -- Pane toggle (0-9)
  for i = 0, 9 do
    create_cmd('ShoTmuxPaneToggle' .. i, function()
      require('shooter.tmux.panes').toggle(i)
    end, { desc = 'Toggle pane ' .. i }, 'ShoPaneToggle' .. i)
  end

  -- Toggle panes picker (configured panes from tmux.yml)
  create_cmd('ShoTmuxTogglePanes', function()
    -- Set up tmux keybinding on first use
    require('shooter.tmux.toggle_panes').setup_tmux_keybinding()
    require('shooter.telescope.toggle_panes_picker').show_picker()
  end, { desc = 'Tmux: toggle configured panes' })

  -- Manually set up tmux keybinding for hiding panes (prefix + H)
  create_cmd('ShoTmuxSetupHideKey', function()
    require('shooter.tmux.toggle_panes').setup_tmux_keybinding()
    vim.notify('Tmux keybinding prefix+H set up for hiding panes', vim.log.levels.INFO)
  end, { desc = 'Tmux: set up prefix+H keybinding for hiding panes' })
end

-- Setup Subproject namespace commands (p prefix in keymaps)
local function setup_subproject_commands()
  local project_mod = require('shooter.core.project')
  local files = require('shooter.core.files')

  -- ShoSubprojectNew
  create_cmd('ShoSubprojectNew', function(opts)
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
      local folders = { '.shooter/ai/shotfiles', '.shooter/ai/shotfiles/archive', '.shooter/ai/shotfiles/backlog',
        '.shooter/ai/shotfiles/done', '.shooter/ai/shotfiles/reqs', '.shooter/ai/shotfiles/test', '.shooter/ai/shotfiles/wait' }
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

  -- ShoSubprojectList
  create_cmd('ShoSubprojectList', function()
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

  -- ShoSubprojectEnsure
  create_cmd('ShoSubprojectEnsure', function()
    local core_files = require('shooter.core.files')
    local git_root = core_files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local project = project_mod.detect_from_cwd()
    local base = project and (git_root .. '/projects/' .. project) or git_root
    local folders = { '.shooter/ai/shotfiles', '.shooter/ai/shotfiles/archive', '.shooter/ai/shotfiles/backlog',
      '.shooter/ai/shotfiles/done', '.shooter/ai/shotfiles/reqs', '.shooter/ai/shotfiles/test', '.shooter/ai/shotfiles/wait' }
    for _, folder in ipairs(folders) do
      vim.fn.mkdir(base .. '/' .. folder, 'p')
    end
    -- Also ensure theme shotfiles from .shooter/themes.json
    local created = core_files.ensure_theme_shotfiles()
    local msg = 'Standard folders ensured'
    if created > 0 then
      msg = msg .. string.format(' + %d theme shotfiles created', created)
    end
    vim.notify(msg, vim.log.levels.INFO)
  end, { desc = 'Ensure standard folders exist' })
end

-- Setup Tool namespace commands (l prefix in keymaps)
local function setup_tool_commands()
  -- ShoToolToken (alias: ShoToolTokenCounter)
  create_cmd('ShoToolToken', function()
    require('shooter.tools.token_counter').show_token_count()
  end, { desc = 'Count tokens' }, 'ShoToolTokenCounter')

  -- ShoToolObsidian (alias: ShoOpenObsidian)
  create_cmd('ShoToolObsidian', function()
    require('shooter.tools.obsidian').open_in_obsidian()
  end, { desc = 'Open in Obsidian' }, 'ShoOpenObsidian')

  -- ShoToolImages (alias: ShoImages)
  create_cmd('ShoToolImages', function()
    require('shooter.images').insert_images()
  end, { desc = 'Insert images' }, 'ShoImages')

  -- ShoToolPrd (alias: ShoPrdList)
  create_cmd('ShoToolPrd', function()
    require('shooter.prd').list()
  end, { desc = 'PRD list' }, 'ShoPrdList')

  -- ShoToolGreenkeep (alias: ShoGreenkeep)
  create_cmd('ShoToolGreenkeep', function()
    require('shooter.core.greenkeep').run()
  end, { desc = 'Convert old date formats' }, 'ShoGreenkeep')

  -- ShoToolSoundTest (alias: ShoSoundTest)
  create_cmd('ShoToolSoundTest', function()
    require('shooter.sound').test()
  end, { desc = 'Test sound' }, 'ShoSoundTest')

  -- ShoToolClipboardPaste - Paste clipboard image
  create_cmd('ShoToolClipboardPaste', function()
    require('shooter.tools.clipboard_image').paste_image_normal()
  end, { desc = 'Paste clipboard image' })

  -- ShoToolClipboardCheck - Check if clipboard has image
  create_cmd('ShoToolClipboardCheck', function()
    require('shooter.tools.clipboard_image').check()
  end, { desc = 'Check clipboard for image' })

  -- ShoToolClipboardImages - Open images directory
  create_cmd('ShoToolClipboardImages', function()
    require('shooter.tools.clipboard_image').open_images_dir()
  end, { desc = 'Open clipboard images folder' })
end

-- Setup Cfg namespace commands (c prefix in keymaps)
local function setup_cfg_commands()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  -- ShoCfgGlobal (alias: ShoEditGlobalContext)
  create_cmd('ShoCfgGlobal', function()
    local global_path = utils.expand_path(config.get('paths.global_context'))
    vim.fn.mkdir(vim.fn.fnamemodify(global_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(global_path))
  end, { desc = 'Edit global context' }, 'ShoEditGlobalContext')

  -- ShoCfgProject (alias: ShoEditProjectContext)
  create_cmd('ShoCfgProject', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      return
    end
    local project_path = git_root .. '/' .. config.get('paths.project_context')
    vim.fn.mkdir(vim.fn.fnamemodify(project_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(project_path))
  end, { desc = 'Edit project context' }, 'ShoEditProjectContext')

  -- ShoCfgPlugin (alias: ShoEditConfig)
  create_cmd('ShoCfgPlugin', function()
    local config_path = utils.find_config_file()
    if not config_path then
      vim.notify('Shooter config file not found', vim.log.levels.WARN)
      return
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
  end, { desc = 'Edit plugin config' }, 'ShoEditConfig')

  -- ShoCfgShot = ShoShotCfg (shot picker config - vimMode)
  create_cmd('ShoCfgShot', function()
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
  vim.api.nvim_create_user_command('ShoShotCfg', function() vim.cmd('ShoCfgShot') end, { desc = 'Toggle shot picker vim mode' })

  -- ShoCfgReload — reload ext_config YAML and reapply syntax
  create_cmd('ShoCfgReload', function()
    local ext_config = require('shooter.core.ext_config')
    ext_config.reload()
    require('shooter.syntax').reapply_all()
    vim.notify('Shooter config reloaded', vim.log.levels.INFO)
  end, { desc = 'Reload YAML config and reapply' })

  -- ShoCfgEditGlobal — open global config.yaml
  create_cmd('ShoCfgEditGlobal', function()
    local ext_config = require('shooter.core.ext_config')
    ext_config.ensure_global_config()
    vim.cmd('edit ' .. vim.fn.fnameescape(ext_config.global_config_path()))
  end, { desc = 'Edit global YAML config' })

  -- ShoCfgEditLocal — open project-local config.yaml
  create_cmd('ShoCfgEditLocal', function()
    local ext_config = require('shooter.core.ext_config')
    local path = ext_config.ensure_local_config()
    if path then
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    else
      vim.notify('Not in a git repository', vim.log.levels.WARN)
    end
  end, { desc = 'Edit project-local YAML config' })

  -- ShoCfgFix — strip invalid keys, fill missing defaults (global only)
  create_cmd('ShoCfgFix', function()
    local ext_config = require('shooter.core.ext_config')
    local bufpath = vim.api.nvim_buf_get_name(0)
    local is_global = bufpath:match('shooter/nvim/config%.yaml$') and not bufpath:match('%.shooter/cfg/nvim/config%.yaml$')
    local is_local = bufpath:match('%.shooter/cfg/nvim/config%.yaml$')
    if not is_global and not is_local then
      vim.notify('Not a shooter config file', vim.log.levels.WARN)
      return
    end
    local removed, added = ext_config.fix_config_buffer(0, is_global)
    local parts = {}
    if removed > 0 then table.insert(parts, 'removed ' .. removed .. ' invalid') end
    if added > 0 then table.insert(parts, 'added ' .. added .. ' missing') end
    if #parts == 0 then table.insert(parts, 'config OK') end
    vim.notify('ShoCfgFix: ' .. table.concat(parts, ', '), vim.log.levels.INFO)
  end, { desc = 'Fix config: strip invalid keys, fill missing defaults' })

  -- ShoCfgShotfile = ShoShotfileCfg (shotfile picker config - sessions)
  create_cmd('ShoCfgShotfile', function()
    local session = require('shooter.session')
    vim.cmd('tabedit ' .. vim.fn.fnameescape(session.get_session_file_path()))
  end, { desc = 'Edit shotfile picker session config' })
  vim.api.nvim_create_user_command('ShoShotfileCfg', function() vim.cmd('ShoCfgShotfile') end, { desc = 'Edit shotfile picker session config' })
end

-- Setup Analytics namespace commands (a prefix in keymaps)
local function setup_analytics_commands()
  -- ShoAnalyticsProject (alias: ShoAnalyticsProject - same name)
  create_cmd('ShoAnalyticsProject', function()
    require('shooter.analytics').show_project()
  end, { desc = 'Project analytics' })

  -- ShoAnalyticsGlobal
  create_cmd('ShoAnalyticsGlobal', function()
    require('shooter.analytics').show_global()
  end, { desc = 'Global analytics' })
end

-- Setup Help namespace commands (h prefix in keymaps)
local function setup_help_commands()
  -- ShoHelp
  create_cmd('ShoHelp', function()
    require('shooter.help').show()
  end, { desc = 'Show help' })

  -- ShoHealth (alias: stays same)
  create_cmd('ShoHealth', function()
    vim.cmd('checkhealth shooter')
  end, { desc = 'Health check' })

  -- ShoHelpDashboard (alias: ShoDashboard)
  create_cmd('ShoHelpDashboard', function()
    require('shooter.dashboard').open()
  end, { desc = 'Open dashboard' }, 'ShoDashboard')

  -- ShoCheatsheet
  create_cmd('ShoCheatsheet', function()
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

  -- ShoNavLastEditedFile - opens most recently modified file in repo
  create_cmd('ShoNavLastEditedFile', function()
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
  vim.api.nvim_create_user_command('ShoRepoOpenLastEditedFile', function()
    vim.cmd('ShoNavLastEditedFile')
  end, { desc = 'Open last edited file in repo' })

  -- ShoNavLastEditedFiles - telescope picker for last N edited files
  create_cmd('ShoNavLastEditedFiles', function(opts)
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

-- Setup git worktree commands (g prefix in keymaps)
local function setup_git_worktree_commands()
  local git_wt = require('shooter.tools.git_worktree')

  create_cmd('ShooterGitWorktreeSwitchTo', function(opts)
    local num = opts.args ~= '' and tonumber(opts.args) or nil
    git_wt.switch_to(num)
  end, { nargs = '?', desc = 'Switch to git worktree by number or pick' })

  create_cmd('ShooterGitWorktreeToMain', function()
    git_wt.to_main()
  end, { desc = 'Switch back to main git worktree' })

  create_cmd('ShooterGitWorktreeLast', function()
    git_wt.to_last()
  end, { desc = 'Switch to last git worktree' })
end

-- Setup utility commands (not in main namespaces)
local function setup_utility_commands()
  -- Filter clearing
  create_cmd('ShoClearFilter', function()
    local filter_state = require('shooter.filter_state')
    filter_state.clear_all_filters()
    vim.notify('Filters cleared', vim.log.levels.INFO)
  end, { desc = 'Clear all filters' })

  -- Inbox (at git root)
  create_cmd('ShoInbox', function()
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
  setup_git_worktree_commands()
  setup_utility_commands()
end

return M
