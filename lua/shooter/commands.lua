-- Command registration for shooter.nvim
-- Organized by namespace: Shotfile, Shot, Tmux, Plan, Tool, Cfg, HalConfig, Analytics, Help

local M = {}

-- Guard: wraps a function so it only runs in shotfiles (docs/shotfiles)
-- Returns the original function wrapped with an is_shooter_file() check
local function require_shotfile(fn)
  return function(opts)
    local files = require('shooter.core.files')
    if not files.is_shooter_file() then
      return
    end
    fn(opts)
  end
end

-- Create a vim user command
local function create_cmd(name, fn, opts)
  vim.api.nvim_create_user_command(name, fn, opts)
end

-- Setup Shotfile namespace commands (f prefix in keymaps)
local function setup_shotfile_commands()
  local files = require('shooter.core.files')
  local movement = require('shooter.core.movement')
  local project_mod = require('shooter.core.project')

  -- HalShooterShotfileNew — create shotfile via Lua
  create_cmd('HalShooterShotfileNew', function(opts)
    local function create_with_title_and_project(title, project)
      if not title or title == '' then return end
      local path = files.create_file(title, '', '', project)
      if path then
        vim.cmd('edit! ' .. vim.fn.fnameescape(path))
        vim.schedule(function()
          -- Cursor on ## shot 1 line, insert mode at end
          local line_count = vim.api.nvim_buf_line_count(0)
          vim.api.nvim_win_set_cursor(0, {math.min(3, line_count), 0})
          vim.cmd('startinsert!')
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
  end, { nargs = '?', desc = 'Create new shotfile' })

  -- ShoShotfileNewInRepo (alias: ShoCreateInRepo)
  create_cmd('HalShooterShotfileNewInRepo', function()
    require('shooter.core.repos').create_in_repo_picker()
  end, { desc = 'Create shotfile in any configured repo' })

  -- ShoShotfilePicker (alias: ShoList)
  create_cmd('HalShooterShotfilePicker', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_files({ include_all_projects = true })
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (current repo)' })

  -- ShoShotfilePickerAll (alias: ShoListAll)
  create_cmd('HalShooterShotfilePickerAll', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_all_repos_files()
    if picker then picker:find() end
  end, { desc = 'Shotfile picker (all repos)' })

  -- HalShooterShotfileLast — Neovim tracking first, hal CLI fallback.
  -- If the shotfile lives in a different git worktree (e.g. main) than the
  -- current cwd (e.g. a numbered worktree), cd to that worktree so buffer and
  -- cwd stay aligned.
  create_cmd('HalShooterShotfileLast', function()
    local last_file = files.get_last_edited_file()
    if not last_file then return end
    files.open_shotfile(last_file)
  end, { desc = 'Open last edited shotfile' })

  -- ShoShotfileRename
  create_cmd('HalShooterShotfileRename', function()
    require('shooter.core.rename').rename_current_file()
  end, { desc = 'Rename current shotfile' })

  -- ShoShotfileDelete
  create_cmd('HalShooterShotfileDelete', function()
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == '' then
      return
    end
    vim.ui.input({ prompt = 'Delete ' .. vim.fn.fnamemodify(bufname, ':t') .. '? (y/n): ' }, function(confirm)
      if confirm == 'y' then
        vim.cmd('bdelete!')
        vim.fn.delete(bufname)
      end
    end)
  end, { desc = 'Delete current shotfile' })

  -- ShoShotfileOpenPrompts (alias: ShoOpenPrompts)
  create_cmd('HalShooterShotfileOpenPrompts', function()
    local config = require('shooter.config')
    local prompts_dir = config.get('paths.prompts_dir')
    vim.fn.mkdir(prompts_dir, 'p')
    -- Auto-create missing theme shotfiles from .hal/util/shooter/themes.json
    local created = files.ensure_theme_shotfiles()
    if created > 0 then
    end
    vim.cmd('Oil ' .. prompts_dir)
  end, { desc = 'Open Oil in prompts folder' })

  -- ShoOpenPlans - Open plans folder in Oil
  create_cmd('HalShooterOpenPlans', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if git_root then
      local plans_dir = git_root .. '/plans'
      vim.fn.mkdir(plans_dir, 'p')
      vim.cmd('Oil ' .. plans_dir)
    else
    end
  end, { desc = 'Open plans folder in Oil' })

  -- ShoOpenShoConfig - Open .hal/util/shooter/config/nvim folder in Oil
  create_cmd('HalShooterOpenShoConfig', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if git_root then
      local shooter_dir = git_root .. '/.hal/util/shooter/config/nvim'
      vim.fn.mkdir(shooter_dir, 'p')
      vim.cmd('Oil ' .. shooter_dir)
    else
    end
  end, { desc = 'Open .hal/util/shooter/config/nvim folder in Oil' })

  -- Move commands
  create_cmd('HalShooterShotfileMoveArchive', movement.move_to_archive, { desc = 'Move to archive' })
  create_cmd('HalShooterShotfileMoveBacklog', movement.move_to_backlog, { desc = 'Move to backlog' })
  create_cmd('HalShooterShotfileMoveDone', movement.move_to_done, { desc = 'Move to done' })
  create_cmd('HalShooterShotfileMovePrompts', movement.move_to_prompts, { desc = 'Move to prompts' })
  create_cmd('HalShooterShotfileMoveReqs', movement.move_to_reqs, { desc = 'Move to reqs' })
  create_cmd('HalShooterShotfileMoveTest', movement.move_to_test, { desc = 'Move to test' })
  create_cmd('HalShooterShotfileMoveWait', movement.move_to_wait, { desc = 'Move to wait' })
  create_cmd('HalShooterShotfileMoveGitRoot', movement.move_to_git_root, { desc = 'Move to git root' })

  -- ShoShotfileMovePicker (alias: ShoMovePicker)
  create_cmd('HalShooterShotfileMovePicker', function()
    require('shooter.core.move_picker').open_picker()
  end, { desc = 'Move file via fuzzy picker' })

  -- HalShooterFixAll — walk every shotfile and apply full cleanup (title, empties, blanks) + commit
  create_cmd('HalShooterFixAll', function()
    local shotfile_fix = require('shooter.core.shotfile_fix')
    local ok, msg = shotfile_fix.run_all()
    require('shooter.utils').echo(msg or (ok and 'shotfiles fix: done' or 'shotfiles fix failed'))
  end, { desc = 'Fix all shotfiles in repo (title, empties, blanks, commit)' })

  -- HalShooterShotfileFix — cleanup current shotfile: title, empty shots, renumber, commit
  create_cmd('HalShooterShotfileFix', require_shotfile(function()
    local ok, msg = require('shooter.core.shotfile_fix').run()
    require('shooter.utils').echo(msg or (ok and 'shotfile fix: done' or 'shotfile fix failed'))
  end), { desc = 'Fix current shotfile: title, empty shots, renumber, commit' })

  -- ShoShotfileCfg = ShoCfgShotfile (bidirectional alias handled in Cfg)
end

-- Setup Shot namespace commands (s prefix in keymaps)
local function setup_shot_commands()
  local shot_actions = require('shooter.core.shot_actions')
  local tmux = require('shooter.tmux')

  -- HalShooterShotNew — create new shot via Lua
  create_cmd('HalShooterShotNew', require_shotfile(shot_actions.create_new_shot),
    { desc = 'Create new shot' })

  -- ShoShotNewWhisper (alias: ShoNewShotWhisper)
  create_cmd('HalShooterShotNewWhisper', require_shotfile(shot_actions.create_new_shot_with_whisper),
    { desc = 'New shot + whisper' })

  -- HalShooterShotDelete — delete last unexecuted shot
  create_cmd('HalShooterShotDelete', require_shotfile(shot_actions.delete_last_shot),
    { desc = 'Delete last shot' })

  -- HalShooterShotToggle — toggle shot executed status and re-sort
  create_cmd('HalShooterShotToggle', require_shotfile(function()
    require('shooter.core.shot_actions').toggle_shot_done()
  end), { desc = 'Toggle shot done' })

  -- HalShooterShotDeleteCursor — delete shot at cursor
  create_cmd('HalShooterShotDeleteCursor', require_shotfile(function()
    require('shooter.core.shot_delete').delete_shot_under_cursor()
  end), { desc = 'Delete shot under cursor' })

  -- ShoShotMove (alias: ShoMoveShot)
  create_cmd('HalShooterShotMove', require_shotfile(function()
    require('shooter.core.shot_move').move_shot()
  end), { desc = 'Move shot to another file' })

  -- HalShooterShotYank — yank shot content
  create_cmd('HalShooterShotYank', require_shotfile(shot_actions.yank_shot),
    { desc = 'Yank shot to clipboard' })

  -- ShoShotViewResponse
  create_cmd('HalShooterShotViewResponse', require_shotfile(function()
    require('shooter.tools.response_viewer').view_response()
  end), { desc = 'View response for shot' })

  -- ShoShotExtractBlock (alias: ShoShotExtract for backward compat)
  create_cmd('HalShooterShotExtractBlock', require_shotfile(shot_actions.extract_subtask),
    { desc = 'Extract ### subtask block to new shot' })

  -- ShoShotExtractLine
  create_cmd('HalShooterShotExtractLine', require_shotfile(shot_actions.extract_line),
    { desc = 'Extract current line to new shot' })

  -- ShoShotMunition (alias: ShoMunition)
  create_cmd('HalShooterShotMunition', require_shotfile(function()
    require('shooter.inbox.picker').show_file_picker()
  end), { desc = 'Import tasks from inbox' })

  -- ShoShotPicker (alias: ShoOpenShots)
  create_cmd('HalShooterShotPicker', require_shotfile(function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_open_shots()
    if picker then picker:find() end
  end), { desc = 'Open shots picker' })

  -- Navigation commands
  create_cmd('HalShooterShotNavNext', require_shotfile(shot_actions.goto_next_open_shot),
    { desc = 'Next open shot' })
  create_cmd('HalShooterShotNavPrev', require_shotfile(shot_actions.goto_prev_open_shot),
    { desc = 'Previous open shot' })
  create_cmd('HalShooterShotNavNextSent', require_shotfile(shot_actions.goto_next_sent_shot),
    { desc = 'Next sent shot' })
  create_cmd('HalShooterShotNavPrevSent', require_shotfile(shot_actions.goto_prev_sent_shot),
    { desc = 'Previous sent shot' })
  create_cmd('HalShooterShotNavLatest', require_shotfile(shot_actions.goto_latest_sent_shot),
    { desc = 'Latest sent shot' })
  create_cmd('HalShooterShotNavUndo', require_shotfile(shot_actions.undo_latest_sent_shot),
    { desc = 'Undo latest sent' })

  -- Send commands with optional pane argument (defaults to 1)
  create_cmd('HalShooterShotSend', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_current_shot(pane)
  end), { nargs = '?', desc = 'Send shot to pane [1-9]' })

  create_cmd('HalShooterShotSendAll', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_all_shots(pane)
  end), { nargs = '?', desc = 'Send all shots to pane [1-9]' })

  create_cmd('HalShooterShotSendVisual', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.send_visual_selection(pane, opts.line1, opts.line2)
  end), { range = true, nargs = '?', desc = 'Send selection to pane [1-9]' })

  create_cmd('HalShooterShotResend', require_shotfile(function(opts)
    local pane = tonumber(opts.args) or 1
    tmux.resend_latest_shot(pane)
  end), { nargs = '?', desc = 'Resend to pane [1-9]' })

  -- Queue commands (1-9)
  local queue = require('shooter.queue')
  for i = 1, 9 do
    create_cmd('HalShooterShotQueue' .. i, require_shotfile(function()
      queue.add_to_queue(nil, i)
    end), { desc = 'Queue for pane ' .. i })
  end

  create_cmd('HalShooterShotQueueView', require_shotfile(function()
    require('shooter.queue.picker').show_queue()
  end), { desc = 'View queue' })

  create_cmd('HalShooterShotQueueClear', require_shotfile(function()
    queue.clear_queue()
  end), { desc = 'Clear queue' })

  -- HalShooterFileStats — stats via Lua
  create_cmd('HalShooterFileStats', require_shotfile(shot_actions.file_stats),
    { desc = 'Shotfile stats (total/open/closed)' })

  -- ShoFileToggleFirstShotOfDayColoring - Toggle day marker highlighting
  create_cmd('HalShooterFileToggleFirstShotOfDayColoring', require_shotfile(function()
    require('shooter.syntax').toggle_day_marker()
  end), { desc = 'Toggle first-shot-of-day coloring' })

  -- ShoShotCreateFromClaude - Cut text from Claude editor and create shot in right pane
  create_cmd('HalShooterShotCreateFromClaude', shot_actions.create_shot_from_claude,
    { desc = 'Cut Claude text, create shot in right pane' })

  -- HalShooterShotsRenumber — renumber via Lua (correct sort: open desc at top, done at bottom)
  create_cmd('HalShooterShotsRenumber', require_shotfile(function()
    local renumber = require('shooter.core.renumber')
    local count = renumber.renumber_shots()
    if count > 0 then
    end
  end), { desc = 'Renumber shots sequentially' })

  -- ShoShotCfg = ShoCfgShot (bidirectional alias handled in Cfg)
end

-- Setup Tmux namespace commands (t prefix in keymaps)
local function setup_tmux_commands()
  local wrapper = require('shooter.tmux.wrapper')

  create_cmd('HalShooterTmuxZoom', wrapper.zoom_toggle, { desc = 'Tmux: zoom toggle' })
  create_cmd('HalShooterTmuxEdit', wrapper.edit_in_vim, { desc = 'Tmux: edit in vim' })
  create_cmd('HalShooterTmuxGit', wrapper.git_status_toggle, { desc = 'Tmux: git status' })
  create_cmd('HalShooterTmuxLight', wrapper.lightswitch, { desc = 'Tmux: light/dark' })
  create_cmd('HalShooterTmuxKillOthers', wrapper.kill_other_panes, { desc = 'Tmux: kill others' })
  create_cmd('HalShooterTmuxReload', wrapper.reload_session, { desc = 'Tmux: reload' })
  create_cmd('HalShooterTmuxDelete', wrapper.delete_session, { desc = 'Tmux: delete session' })
  create_cmd('HalShooterTmuxSmug', wrapper.smug_load, { desc = 'Tmux: smug load' })
  create_cmd('HalShooterTmuxYank', wrapper.yank_to_vim, { desc = 'Tmux: yank to vim' })
  create_cmd('HalShooterTmuxChoose', wrapper.choose_session, { desc = 'Tmux: choose session' })
  create_cmd('HalShooterTmuxSwitch', wrapper.switch_last, { desc = 'Tmux: switch last' })

  -- ShoTmuxWatch (alias: ShoWatch)
  create_cmd('HalShooterTmuxWatch', function()
    require('shooter.tmux.watch').open_watch_pane()
  end, { desc = 'Tmux: watch pane' })

  -- Pane toggle (0-9)
  for i = 0, 9 do
    create_cmd('HalShooterTmuxPaneToggle' .. i, function()
      require('shooter.tmux.panes').toggle(i)
    end, { desc = 'Toggle pane ' .. i })
  end

  -- Toggle panes picker (configured panes from tmux.yml)
  create_cmd('HalShooterTmuxTogglePanes', function()
    -- Set up tmux keybinding on first use
    require('shooter.tmux.toggle_panes').setup_tmux_keybinding()
    require('shooter.telescope.toggle_panes_picker').show_picker()
  end, { desc = 'Tmux: toggle configured panes' })

  -- Manually set up tmux keybinding for hiding panes (prefix + H)
  create_cmd('HalShooterTmuxSetupHideKey', function()
    require('shooter.tmux.toggle_panes').setup_tmux_keybinding()
  end, { desc = 'Tmux: set up prefix+H keybinding for hiding panes' })
end

-- Setup Plan namespace commands (p prefix in keymaps)
local function setup_plan_commands()
  local files = require('shooter.core.files')
  local plan_picker = require('shooter.plans.picker')
  local utils = require('shooter.utils')

  local function open(basename)
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    plan_picker.open(git_root, basename)
  end

  create_cmd('HalShooterPlanPickerPlan',    function() open('plan')    end,
    { desc = 'Pick a docs/plans/**/plan.md file' })
  create_cmd('HalShooterPlanPickerContext', function() open('context') end,
    { desc = 'Pick a docs/plans/**/context.md file' })
  create_cmd('HalShooterPlanPickerSpec',    function() open('spec')    end,
    { desc = 'Pick a docs/plans/**/spec.md file' })

  create_cmd('HalShooterPlanPickerShotfile', function()
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    plan_picker.open_shotfiles(git_root)
  end, { desc = 'Pick a docs/shotfiles/docs/plans/*.md plan shotfile' })

  -- HalShooterPlanEdit — open/create/rename shotfile for plan under cursor
  create_cmd('HalShooterPlanEdit', function()
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local ok, msg = masterplan.edit_plan_at_line(git_root, line)
    if not ok then
      utils.echo('PlanEdit: ' .. (msg or 'unknown'))
    else
      utils.echo('plan: ' .. msg)
    end
  end, { desc = 'Edit shotfile for plan under cursor (create/rename/open)' })

  -- HalShooterPlanNew — create a new docs/plans/<NNNN-slug>/plan.md
  create_cmd('HalShooterPlanNew', function(opts)
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local function create(title)
      if not title or title == '' then return end
      local ok, path_or_err = masterplan.new_plan(git_root, title)
      if not ok then
        utils.echo('PlanNew: ' .. (path_or_err or 'unknown'))
        return
      end
      vim.cmd('edit ' .. vim.fn.fnameescape(path_or_err))
    end
    if opts.args ~= '' then
      create(opts.args)
    else
      vim.ui.input({ prompt = 'Plan title: ' }, create)
    end
  end, { nargs = '?', desc = 'Create new plan under docs/plans/<NNNN-slug>/' })

  -- HalShooterPlanRename — rename the plan under the cursor in masterplan.md
  create_cmd('HalShooterPlanRename', function()
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local old_name = masterplan.extract_plan_name(line)
    if not old_name then
      utils.echo('PlanRename: cursor not on a plan line')
      return
    end
    vim.ui.input({ prompt = 'rename plan: ', default = old_name },
      function(new_name)
        if not new_name or new_name == '' then return end
        if new_name == old_name then return end
        local ok, msg = masterplan.rename_plan(git_root, old_name, new_name)
        utils.echo(ok and ('plan: ' .. msg) or ('PlanRename: ' .. (msg or 'unknown')))
      end)
  end, { desc = 'Rename plan under cursor (folder + shotfile + masterplan)' })

  -- HalShooterPlanDelete — delete the plan under the cursor in masterplan.md.
  -- Folder and shotfile are each confirmed separately when they contain more
  -- than a title; stub-only artifacts are removed without prompting.
  create_cmd('HalShooterPlanDelete', function()
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local name = masterplan.extract_plan_name(line)
    if not name then
      utils.echo('PlanDelete: cursor not on a plan line')
      return
    end

    local folder = git_root .. '/docs/plans/' .. name
    local shotfile = git_root .. '/docs/shotfiles/docs/plans/'
      .. name .. '.md'
    local folder_exists = vim.fn.isdirectory(folder) == 1
    local shotfile_exists = vim.fn.filereadable(shotfile) == 1
    local folder_has_content = folder_exists
      and masterplan.folder_has_content(folder)
    local shotfile_has_content = shotfile_exists
      and not masterplan.is_stub_file(shotfile)

    -- Chain the two confirmation prompts, then invoke delete_plan with the
    -- resolved choices. A missing artifact is a "no-op delete" (opts flag
    -- set to true; delete_plan tolerates missing paths).
    local function run(folder_ok, shotfile_ok)
      if not folder_ok and not shotfile_ok
         and not folder_exists and not shotfile_exists then
        -- Nothing to delete on disk; still drop the masterplan entry.
        folder_ok = true; shotfile_ok = true
      end
      if not folder_ok and not shotfile_ok then
        utils.echo('PlanDelete: aborted')
        return
      end
      local ok, msg = masterplan.delete_plan(git_root, name,
        { folder = folder_ok, shotfile = shotfile_ok })
      utils.echo(ok and ('plan: ' .. msg) or ('PlanDelete: ' .. (msg or 'unknown')))
    end

    local function prompt_shotfile(folder_ok)
      if not shotfile_exists then run(folder_ok, false); return end
      if not shotfile_has_content then run(folder_ok, true); return end
      vim.ui.input({ prompt = 'delete shotfile ' .. name .. '.md (has content)? type yes: ' },
        function(ans) run(folder_ok, ans == 'yes') end)
    end

    if not folder_exists then
      prompt_shotfile(false)
      return
    end
    if not folder_has_content then
      prompt_shotfile(true)
      return
    end
    vim.ui.input({ prompt = 'delete folder docs/plans/' .. name .. '/ (has content)? type yes: ' },
      function(ans) prompt_shotfile(ans == 'yes') end)
  end, { desc = 'Delete plan under cursor (folder + shotfile + masterplan)' })
end

-- Setup Tool namespace commands (l prefix in keymaps)
local function setup_tool_commands()
  -- ShoToolToken (alias: ShoToolTokenCounter)
  create_cmd('HalShooterToolToken', function()
    require('shooter.tools.token_counter').show_token_count()
  end, { desc = 'Count tokens' })

  -- ShoToolObsidian (alias: ShoOpenObsidian)
  create_cmd('HalShooterToolObsidian', function()
    require('shooter.tools.obsidian').open_in_obsidian()
  end, { desc = 'Open in Obsidian' })

  -- ShoToolImages (alias: ShoImages)
  create_cmd('HalShooterToolImages', function()
    require('shooter.images').insert_images()
  end, { desc = 'Insert images' })

  -- ShoToolPrd (alias: ShoPrdList)
  create_cmd('HalShooterToolPrd', function()
    require('shooter.prd').list()
  end, { desc = 'PRD list' })

  -- ShoToolGreenkeep (alias: ShoGreenkeep)
  create_cmd('HalShooterToolGreenkeep', function()
    require('shooter.core.greenkeep').run()
  end, { desc = 'Convert old date formats' })

  -- ShoToolSoundTest (alias: ShoSoundTest)
  create_cmd('HalShooterToolSoundTest', function()
    require('shooter.sound').test()
  end, { desc = 'Test sound' })

  -- ShoToolClipboardPaste - Paste clipboard image
  create_cmd('HalShooterToolClipboardPaste', function()
    require('shooter.tools.clipboard_image').paste_image_normal()
  end, { desc = 'Paste clipboard image' })

  -- ShoToolClipboardCheck - Check if clipboard has image
  create_cmd('HalShooterToolClipboardCheck', function()
    require('shooter.tools.clipboard_image').check()
  end, { desc = 'Check clipboard for image' })

  -- ShoToolClipboardImages - Open images directory
  create_cmd('HalShooterToolClipboardImages', function()
    require('shooter.tools.clipboard_image').open_images_dir()
  end, { desc = 'Open clipboard images folder' })
end

-- Setup Cfg namespace commands (c prefix in keymaps)
local function setup_cfg_commands()
  local config = require('shooter.config')
  local utils = require('shooter.utils')

  -- ShoCfgGlobal (alias: ShoEditGlobalContext)
  create_cmd('HalShooterCfgGlobal', function()
    local global_path = utils.expand_path(config.get('paths.global_context'))
    vim.fn.mkdir(vim.fn.fnamemodify(global_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(global_path))
  end, { desc = 'Edit global context' })

  -- ShoCfgProject (alias: ShoEditProjectContext)
  create_cmd('HalShooterCfgProject', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      return
    end
    local project_path = git_root .. '/' .. config.get('paths.project_context')
    vim.fn.mkdir(vim.fn.fnamemodify(project_path, ':h'), 'p')
    vim.cmd('edit ' .. vim.fn.fnameescape(project_path))
  end, { desc = 'Edit project context' })

  -- ShoCfgPlugin (alias: ShoEditConfig)
  create_cmd('HalShooterCfgPlugin', function()
    local config_path = utils.find_config_file()
    if not config_path then
      return
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
  end, { desc = 'Edit plugin config' })

  -- ShoCfgShot = ShoShotCfg (shot picker config - vimMode)
  create_cmd('HalShooterCfgShot', function()
    local session = require('shooter.session')
    local current = session.get_current_session()
    local modes = { 'normal', 'insert' }
    local current_mode = current.vimMode and current.vimMode.shotPicker or 'normal'
    local next_idx = 1
    for i, m in ipairs(modes) do
      if m == current_mode then next_idx = (i % #modes) + 1 end
    end
    session.set_vim_mode('shotPicker', modes[next_idx])
  end, { desc = 'Toggle shot picker vim mode' })

  -- ShoCfgReload — reload ext_config YAML and reapply syntax
  create_cmd('HalShooterCfgReload', function()
    local ext_config = require('shooter.core.ext_config')
    ext_config.reload()
    require('shooter.syntax').reapply_all()
  end, { desc = 'Reload YAML config and reapply' })

  -- ShoCfgEditGlobal — open global config.yaml
  create_cmd('HalShooterCfgEditGlobal', function()
    local ext_config = require('shooter.core.ext_config')
    ext_config.ensure_global_config()
    vim.cmd('edit ' .. vim.fn.fnameescape(ext_config.global_config_path()))
  end, { desc = 'Edit global YAML config' })

  -- ShoCfgEditLocal — open project-local config.yaml
  create_cmd('HalShooterCfgEditLocal', function()
    local ext_config = require('shooter.core.ext_config')
    local path = ext_config.ensure_local_config()
    if path then
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    else
    end
  end, { desc = 'Edit project-local YAML config' })

  -- ShoCfgFix — strip invalid keys, fill missing defaults (global only)
  create_cmd('HalShooterCfgFix', function()
    local ext_config = require('shooter.core.ext_config')
    local bufpath = vim.api.nvim_buf_get_name(0)
    local is_global = bufpath:match('hal/util/shooter/nvim/config%.yaml$')
    local is_local = bufpath:match('%.hal/util/shooter/cfg/nvim/config%.yaml$')
    if not is_global and not is_local then
      return
    end
    local removed, added = ext_config.fix_config_buffer(0, is_global)
    local parts = {}
    if removed > 0 then table.insert(parts, 'removed ' .. removed .. ' invalid') end
    if added > 0 then table.insert(parts, 'added ' .. added .. ' missing') end
    if #parts == 0 then table.insert(parts, 'config OK') end
  end, { desc = 'Fix config: strip invalid keys, fill missing defaults' })

  -- ShoCfgShotfile = ShoShotfileCfg (shotfile picker config - sessions)
  create_cmd('HalShooterCfgShotfile', function()
    local session = require('shooter.session')
    vim.cmd('tabedit ' .. vim.fn.fnameescape(session.get_session_file_path()))
  end, { desc = 'Edit shotfile picker session config' })
end

-- Setup Hal domain config commands (ConfigShow opens readonly, ConfigEdit opens for editing)
local function setup_hal_config_commands()
  -- All hal domains with config show/edit support and their config directory names
  local domains = {
    { name = 'Agent',    dir = 'agent' },
    { name = 'Api',      dir = 'api' },
    { name = 'Compose',  dir = 'docker-compose' },
    { name = 'Daemon',   dir = 'daemon' },
    { name = 'Env',      dir = 'env' },
    { name = 'Mcp',      dir = 'mcp' },
    { name = 'Port',     dir = 'port' },
    { name = 'Repo',     dir = 'repo' },
    { name = 'Server',   dir = 'server' },
    { name = 'Shooter',  dir = 'shooter' },
    { name = 'Smug',     dir = 'smug' },
    { name = 'Sync',     dir = 'sync' },
    { name = 'Template', dir = 'template' },
    { name = 'Youtube',  dir = 'youtube' },
  }

  local home = vim.fn.expand('~')

  for _, domain in ipairs(domains) do
    local config_path = home .. '/.config/hal/' .. domain.dir .. '/config.yml'

    -- Hal<Domain>ConfigShow — open config in a readonly split
    create_cmd('Hal' .. domain.name .. 'ConfigShow', function()
      if vim.fn.filereadable(config_path) ~= 1 then
        return
      end
      vim.cmd('split ' .. vim.fn.fnameescape(config_path))
      vim.bo.readonly = true
      vim.bo.modifiable = false
    end, { desc = 'Show hal ' .. domain.dir .. ' config' })

    -- Hal<Domain>ConfigEdit — open config for editing (create if missing)
    create_cmd('Hal' .. domain.name .. 'ConfigEdit', function()
      local dir = vim.fn.fnamemodify(config_path, ':h')
      vim.fn.mkdir(dir, 'p')
      if vim.fn.filereadable(config_path) ~= 1 then
        local file = io.open(config_path, 'w')
        if file then
          file:write('# hal config — see https://github.com/divramod/hal\n')
          file:close()
        end
      end
      vim.cmd('edit ' .. vim.fn.fnameescape(config_path))
    end, { desc = 'Edit hal ' .. domain.dir .. ' config' })
  end
end

-- Setup Analytics namespace commands (a prefix in keymaps)
local function setup_analytics_commands()
  create_cmd('HalShooterAnalyticsProject', function()
    require('shooter.analytics').show_project()
  end, { desc = 'Project analytics' })

  create_cmd('HalShooterAnalyticsGlobal', function()
    require('shooter.analytics').show_global()
  end, { desc = 'Global analytics' })
end

-- Setup Help namespace commands (h prefix in keymaps)
local function setup_help_commands()
  -- ShoHelp
  create_cmd('HalShooterHelp', function()
    require('shooter.help').show()
  end, { desc = 'Show help' })

  -- ShoHealth (alias: stays same)
  create_cmd('HalShooterHealth', function()
    vim.cmd('checkhealth shooter')
  end, { desc = 'Health check' })

  -- ShoHelpDashboard (alias: ShoDashboard)
  create_cmd('HalShooterHelpDashboard', function()
    require('shooter.dashboard').open()
  end, { desc = 'Open dashboard' })

  -- ShoCheatsheet
  create_cmd('HalShooterCheatsheet', function()
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
  create_cmd('HalShooterNavLastEditedFile', function()
    local git_root = files.get_cwd_git_root()
    if not git_root then
      return
    end
    local results = get_last_edited_files(git_root, 1)
    if #results > 0 then
      vim.cmd('edit ' .. vim.fn.fnameescape(results[1]))
    else
    end
  end, { desc = 'Open last edited file in repo' })

  -- Alias for backward compatibility

  -- ShoNavLastEditedFiles - telescope picker for last N edited files
  create_cmd('HalShooterNavLastEditedFiles', function(opts)
    local git_root = files.get_cwd_git_root()
    if not git_root then
      return
    end
    local count = tonumber(opts.args) or 10
    local results = get_last_edited_files(git_root, count)
    if #results == 0 then
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
      attach_mappings = function(prompt_bufnr, map)
        require('shooter.keymaps.picker').setup_nav_keymaps(map)
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

  create_cmd('HalShooteroterGitWorktreeSwitchTo', function(opts)
    local num = opts.args ~= '' and tonumber(opts.args) or nil
    git_wt.switch_to(num)
  end, { nargs = '?', desc = 'Switch to git worktree by number or pick' })

  create_cmd('HalShooteroterGitWorktreeToMain', function()
    git_wt.to_main()
  end, { desc = 'Switch back to main git worktree' })

  create_cmd('HalShooteroterGitWorktreeLast', function()
    git_wt.to_last()
  end, { desc = 'Switch to last git worktree' })
end

-- Setup utility commands (not in main namespaces)
local function setup_utility_commands()
  -- Filter clearing
  create_cmd('HalShooterClearFilter', function()
    local filter_state = require('shooter.filter_state')
    filter_state.clear_all_filters()
  end, { desc = 'Clear all filters' })

  -- Inbox (at git root)
  create_cmd('HalShooterInbox', function()
    local files = require('shooter.core.files')
    local git_root = files.get_git_root()
    if not git_root then
      return
    end
    local inbox_path = git_root .. '/INBOX.md'
    if vim.fn.filereadable(inbox_path) ~= 1 then
      local file = io.open(inbox_path, 'w')
      if file then file:write('# Inbox\n\n'); file:close() end
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(inbox_path))
  end, { desc = 'Open INBOX.md at git root' })

  -- Masterplan (docs/plans/masterplan.md at git root)
  create_cmd('HalShooterMasterplanOpen', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    masterplan.fix(git_root)
    vim.cmd('edit ' .. vim.fn.fnameescape(masterplan.get_path(git_root)))
  end, { desc = 'Open docs/plans/masterplan.md at git root (fix on open)' })

  -- HalShooterMasterplanFix — normalize title, sections, numbering, slugs,
  -- sync plan shotfiles, then git-add+commit (no push) the plan folders.
  create_cmd('HalShooterMasterplanFix', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    local ok, err = masterplan.fix(git_root)
    if not ok then
      utils.echo('masterplan fix failed: ' .. (err or ''))
      return
    end
    local cok, cmsg, committed = masterplan.commit_plans(git_root)
    if not cok then
      utils.echo('masterplan: fixed; commit failed: ' .. (cmsg or ''))
    elseif committed then
      utils.echo('masterplan: fixed + committed')
    else
      utils.echo('masterplan: fixed (' .. (cmsg or 'no changes to commit') .. ')')
    end
  end, { desc = 'Fix masterplan.md and commit docs/plans + plan shotfiles' })

  -- HalShooterMasterplanOpen{Plan,Context,Spec} — open the docs/plans/<plan>/
  -- <kind>.md file for the plan under cursor
  local function open_plan_file(kind)
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then utils.echo('Not in a git repo'); return end
    local line = vim.api.nvim_get_current_line()
    local ok, msg = masterplan.open_plan_file(git_root, line, kind)
    if not ok then utils.echo('masterplan: ' .. (msg or 'unknown')) end
  end
  create_cmd('HalShooterMasterplanOpenPlan',    function() open_plan_file('plan')    end,
    { desc = 'Open docs/plans/<plan>/plan.md for plan under cursor' })
  create_cmd('HalShooterMasterplanOpenContext', function() open_plan_file('context') end,
    { desc = 'Open docs/plans/<plan>/context.md for plan under cursor' })
  create_cmd('HalShooterMasterplanOpenSpec',    function() open_plan_file('spec')    end,
    { desc = 'Open docs/plans/<plan>/spec.md for plan under cursor' })

  -- HalShooterMasterplanMarkDone — move plan under cursor to ## done
  create_cmd('HalShooterMasterplanMarkDone', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local masterplan = require('shooter.plans.masterplan')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local ok, err = masterplan.mark_done(git_root, lnum)
    utils.echo(ok and 'masterplan: marked done' or ('masterplan mark done failed: ' .. (err or '')))
  end, { desc = 'Move plan under cursor to ## done with timestamp' })

  -- HalShooterGitPush — add/commit/push the shotfiles tree
  create_cmd('HalShooterGitPush', function()
    local files = require('shooter.core.files')
    local utils = require('shooter.utils')
    local git_push = require('shooter.core.git_push')
    local git_root = files.get_git_root()
    if not git_root then
      utils.echo('Not in a git repo')
      return
    end
    local ok, msg = git_push.run(git_root)
    utils.echo(msg or (ok and 'shotfiles: done' or 'git push failed'))
  end, { desc = 'git add/commit/push docs/shotfiles' })

  -- HalShooterShotfileMergeInto — pick a target shotfile and merge the
  -- current shotfile's shots into it, deleting the current file afterwards.
  create_cmd('HalShooterShotfileMergeInto', require_shotfile(function()
    local source_path = vim.api.nvim_buf_get_name(0)
    if source_path == '' then
      require('shooter.utils').echo('no current file')
      return
    end

    local helpers = require('shooter.telescope.helpers')
    local tele_pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    local all = helpers.get_prompt_files({ include_all_projects = true })
    local candidates = {}
    for _, entry in ipairs(all) do
      if entry.path ~= source_path then table.insert(candidates, entry) end
    end
    if #candidates == 0 then
      require('shooter.utils').echo('no other shotfile to merge into')
      return
    end

    tele_pickers.new({}, {
      prompt_title = 'Merge into shotfile',
      layout_strategy = 'vertical',
      layout_config = { width = 0.8, height = 0.6 },
      finder = finders.new_table({
        results = candidates,
        entry_maker = function(e)
          return { value = e, display = e.display, ordinal = e.display, path = e.path }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry or not entry.value or not entry.value.path then return end
          local target_path = entry.value.path
          vim.ui.input({
            prompt = 'Merge into ' .. vim.fn.fnamemodify(target_path, ':t')
              .. '? (y/n): '
          }, function(confirm)
            if confirm == 'y' then
              local merge = require('shooter.core.shotfile_merge')
              local ok, msg = merge.merge_into(source_path, target_path)
              require('shooter.utils').echo(msg or (ok and 'merged' or 'merge failed'))
            end
          end)
        end)
        map('n', '<C-c>', actions.close, { desc = 'close' })
        map('n', 'q', actions.close, { desc = 'close' })
        return true
      end,
    }):find()
  end), { desc = 'Merge current shotfile into another (pick target)' })

  -- HalShooterOpenLinkPicker — telescope picker of links in the current
  -- buffer; select to open in browser / nvim / oil / system opener.
  create_cmd('HalShooterOpenLinkPicker', function()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local links = require('shooter.tools.links')
    local entries = links.collect_from_lines(lines, nil)
    table.sort(entries, function(a, b)
      if a.line == b.line then return a.col < b.col end
      return a.line < b.line
    end)
    require('shooter.telescope.link_picker').open(entries, {
      title = 'Links in ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t'),
    })
  end, { desc = 'Open link picker for current buffer' })

  -- HalShooterOpenLinkPickerTmux — collect links from every tmux pane in
  -- the current window and open them via the same picker.
  create_cmd('HalShooterOpenLinkPickerTmux', function()
    local tmux = require('shooter.tools.tmux_panes')
    if not tmux.in_tmux() then
      require('shooter.utils').echo('not inside a tmux session')
      return
    end
    local panes, err = tmux.list_current_window()
    if err or #panes == 0 then
      require('shooter.utils').echo(err or 'no tmux panes')
      return
    end
    local links = require('shooter.tools.links')
    local all = {}
    for _, pane in ipairs(panes) do
      local pane_lines = tmux.capture(pane.id)
      if pane_lines then
        local pane_entries = links.collect_from_lines(pane_lines, pane.title)
        for _, e in ipairs(pane_entries) do table.insert(all, e) end
      end
    end
    require('shooter.telescope.link_picker').open(all, {
      title = 'Links in tmux window',
      with_source = true,
    })
  end, { desc = 'Open link picker for tmux window panes' })

  -- HalShooterGitWorktreeOpenOil — open oil at the parallel folder of the
  -- current file in another worktree, without changing cwd.
  create_cmd('HalShooterGitWorktreeOpenOil', function(opts)
    local number = tonumber(opts.args)
    if not number then
      require('shooter.utils').echo('usage: :HalShooterGitWorktreeOpenOil <number>')
      return
    end
    require('shooter.tools.git_worktree_oil').open_in_worktree(number)
  end, { nargs = 1, desc = 'Open oil at parallel folder in worktree <n>' })

end

-- Setup Domain namespace commands (d prefix in keymaps)
local function setup_domain_commands()
  local domain = require('shooter.core.domain')

  create_cmd('HalShooterDomainNew', function(opts)
    if opts.args ~= '' then
      domain.create_domain(opts.args)
    else
      vim.ui.input({ prompt = 'Domain name: ' }, function(name)
        if name and name ~= '' then domain.create_domain(name) end
      end)
    end
  end, { nargs = '?', desc = 'Create new domain' })

  create_cmd('HalShooterDomainMoveShotfileToDomain', require_shotfile(function()
    domain.pick_and_move()
  end), { desc = 'Move shotfile to domain' })

  create_cmd('HalShooterDomainRename', function()
    domain.rename()
  end, { desc = 'Rename domain' })
end

-- Setup Session namespace commands (sc prefix in keymaps)
local function setup_session_commands()
  for i = 1, 9 do
    create_cmd('HalShooterSessionClear' .. i, function()
      local detect = require('shooter.tmux.detect')
      local utils = require('shooter.utils')

      local pane_id, err = detect.find_ai_pane(i)
      if not pane_id then
        utils.echo(err or 'No AI pane found')
        return
      end

      -- Safety: never send to nvim's own pane
      local nvim_pane = vim.trim(vim.fn.system({"tmux", "display-message", "-p", "#{pane_id}"}))
      if pane_id == nvim_pane then
        utils.echo('Error: AI pane ID matches nvim pane, aborting')
        return
      end

      vim.fn.system(string.format(
        "tmux send-keys -t %s C-c && sleep 0.05 && tmux send-keys -t %s C-u && sleep 0.1 && tmux send-keys -t %s /clear Enter",
        pane_id, pane_id, pane_id
      ))
      utils.echo('Cleared session in pane ' .. i)
    end, { desc = 'Clear AI session ' .. i })
  end
end

-- Setup HalConfigPicker — telescope picker for all .yml files under ~/.config/hal
local function setup_hal_config_picker()
  create_cmd('HalConfigPicker', function()
    local home = vim.fn.expand('~')
    local hal_dir = home .. '/.config/hal'

    local handle = io.popen(string.format('find "%s" -name "*.yml" -type f 2>/dev/null | sort', hal_dir))
    if not handle then
      vim.notify('Could not scan ' .. hal_dir, vim.log.levels.WARN)
      return
    end
    local results = {}
    for line in handle:lines() do
      if line ~= '' then table.insert(results, line) end
    end
    handle:close()

    if #results == 0 then
      vim.notify('No .yml files found in ' .. hal_dir, vim.log.levels.INFO)
      return
    end

    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    local previewers = require('telescope.previewers')

    pickers.new({}, {
      prompt_title = 'Hal Config (~/.config/hal)',
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          local short = entry:gsub('^' .. vim.pesc(hal_dir) .. '/', '')
          return { value = entry, display = short, ordinal = short }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        title = 'Config Preview',
        define_preview = function(self, entry)
          conf.buffer_previewer_maker(entry.value, self.state.bufnr, {
            bufname = self.state.bufname,
          })
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        require('shooter.keymaps.picker').setup_nav_keymaps(map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then vim.cmd('edit ' .. vim.fn.fnameescape(selection.value)) end
        end)
        return true
      end,
    }):find()
  end, { desc = 'Pick hal config file (~/.config/hal)' })
end

-- Setup Bullet namespace commands (b prefix in keymaps)
local function setup_bullet_commands()
  create_cmd('HalShooterBulletPickerCurrentFile', require_shotfile(function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_bullets_current_file()
    if picker then picker:find() end
  end), { desc = 'Bullet picker (current file)' })

  create_cmd('HalShooterBulletPickerCurrentRepo', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_bullets_current_repo()
    if picker then picker:find() end
  end, { desc = 'Bullet picker (current repo)' })

  create_cmd('HalShooterBulletPickerAllRepos', function()
    local pickers = require('shooter.telescope.pickers')
    local picker = pickers.list_bullets_all_repos()
    if picker then picker:find() end
  end, { desc = 'Bullet picker (all repos)' })
end

-- Setup all vim commands
function M.setup()
  setup_shotfile_commands()
  setup_shot_commands()
  setup_bullet_commands()
  setup_tmux_commands()
  setup_plan_commands()
  setup_domain_commands()
  setup_session_commands()
  setup_tool_commands()
  setup_cfg_commands()
  setup_hal_config_commands()
  setup_hal_config_picker()
  setup_analytics_commands()
  setup_help_commands()
  setup_nav_commands()
  setup_git_worktree_commands()
  setup_utility_commands()
end

return M
