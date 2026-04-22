-- Telescope pickers for shooter.nvim
local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local utils = require('shooter.utils')
local previewers_mod = require('shooter.telescope.previewers')
local telescope_actions = require('shooter.telescope.actions')
local helpers = require('shooter.telescope.helpers')
local session = require('shooter.session')
local session_filter = require('shooter.session.filter')
local session_sort = require('shooter.session.sort')
local session_picker = require('shooter.session.picker')
local shooter_config = require('shooter.config')
local recency = require('shooter.telescope.recency')

-- Re-export clear_selection from helpers for external access
M.clear_selection = helpers.clear_selection

-- Build title string showing session and active filters
local function build_picker_title(base_title)
  local current = session.get_current_session()
  local filter_status = session_filter.get_filter_status(current)
  local sort_status = session_sort.get_sort_status(current)
  local parts = { base_title }
  local indicators = { current.name, filter_status }
  if sort_status ~= 'default' then
    table.insert(indicators, 'sort:' .. sort_status)
  end
  table.insert(parts, '[' .. table.concat(indicators, ' | ') .. ']')
  table.insert(parts, '(?=help)')
  return table.concat(parts, ' ')
end

-- Setup folder toggle mappings (1-6 and a/b/t/e/w/f)
local function setup_folder_mappings(prompt_bufnr, map, refresh_fn)
  local folder_keys = {
    ['1'] = 'archive', ['a'] = 'archive',
    ['2'] = 'backlog', ['b'] = 'backlog',
    ['3'] = 'done', ['t'] = 'done',
    ['4'] = 'reqs', ['e'] = 'reqs',
    ['5'] = 'wait', ['w'] = 'wait',
    ['6'] = 'prompts', ['f'] = 'prompts',
  }
  for key, folder in pairs(folder_keys) do
    map('n', key, function()
      local new_state = session.toggle_folder(folder)
      local msg = folder .. ': ' .. (new_state and 'ON' or 'OFF')
      refresh_fn(prompt_bufnr)
    end, { desc = 'toggle: ' .. folder })
  end
  -- 'A' toggles between all folders and prompts-only
  map('n', 'A', function()
    local all_enabled = session.toggle_all_folders()
    local msg = all_enabled and 'All folders enabled' or 'Prompts only'
    refresh_fn(prompt_bufnr)
  end, { desc = 'toggle all folders' })
end

-- Setup session command mappings (ss/sl/sn/sd/sr)
local function setup_session_mappings(prompt_bufnr, map, refresh_fn)
  -- ss: save session (manual)
  map('n', 'ss', function()
    session.save_current()
  end, { desc = 'save session' })

  -- sl: load session
  map('n', 'sl', function()
    actions.close(prompt_bufnr)
    session_picker.show_session_picker(function()
      M.list_all_files({ initial_mode = 'normal' }):find()
    end)
  end, { desc = 'load session' })

  -- sn: new session
  map('n', 'sn', function()
    actions.close(prompt_bufnr)
    session_picker.show_new_session_prompt(function()
      M.list_all_files({ initial_mode = 'normal' }):find()
    end)
  end, { desc = 'new session' })

  -- sd: delete session
  map('n', 'sd', function()
    vim.ui.input({ prompt = 'Delete session? (y/n): ' }, function(confirm)
      if confirm == 'y' then
        local name = session.get_current_session_name()
        session.delete_current_session()
        refresh_fn(prompt_bufnr)
      end
    end)
  end, { desc = 'delete session' })

  -- sr: rename session
  map('n', 'sr', function()
    actions.close(prompt_bufnr)
    session_picker.show_rename_prompt(function()
      M.list_all_files({ initial_mode = 'normal' }):find()
    end)
  end, { desc = 'rename session' })
end

-- Create file picker with session-based filtering
local function create_file_picker(opts, get_files_fn, title_prefix, git_root_override)
  opts = opts or {}
  local files_mod = require('shooter.core.files')
  local git_root = git_root_override or files_mod.get_git_root()

  -- Reload session from disk in case user edited the YAML file
  session.reload_from_disk()
  -- Clear sort metadata cache so mtime reflects current state
  session_sort.clear_cache()

  -- Get all files then apply session filters
  local all_files = get_files_fn()
  local current = session.get_current_session()
  local filtered = session_filter.apply_filters(all_files, current, git_root)
  -- Apply session sort criteria (default: modified desc)
  local sorted = session_sort.sort_files(filtered, current)
  -- Ensure _mtime is populated for age display
  local now = os.time()
  for _, e in ipairs(sorted) do
    if not e._mtime then
      e._mtime = recency.file_mtime(e.path)
    end
    e.display = recency.append_age(e.display, e._mtime, now)
  end

  local title = build_picker_title(title_prefix)
  if #sorted == 0 then
    title = title .. ' (no matching files)'
  end

  local function refresh_picker(prompt_bufnr)
    session_sort.clear_cache()
    local new_files = get_files_fn()
    local new_current = session.get_current_session()
    local new_filtered = session_filter.apply_filters(new_files, new_current, git_root)
    local new_sorted = session_sort.sort_files(new_filtered, new_current)
    local refresh_now = os.time()
    for _, e in ipairs(new_sorted) do
      if not e._mtime then
        e._mtime = recency.file_mtime(e.path)
      end
      e.display = recency.append_age(e.display, e._mtime, refresh_now)
    end
    local picker = action_state.get_current_picker(prompt_bufnr)
    picker.prompt_border:change_title(build_picker_title(title_prefix))
    picker:refresh(finders.new_table({
      results = new_sorted,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }), { reset_prompt = false })
  end

  -- Get initial mode from session vimMode setting (default to insert)
  local vim_mode = current.vimMode and current.vimMode.shotfilePicker or 'insert'
  local initial_mode = opts.initial_mode or vim_mode
  local layout = current.layout or 'vertical'
  local layout_config = layout == 'vertical'
    and { width = 0.95, height = 0.9, preview_height = 0.5 }
    or { width = 0.95, preview_width = 0.5 }

  local picker_instance = pickers.new(opts, {
    prompt_title = title,
    layout_strategy = layout,
    layout_config = layout_config,
    initial_mode = initial_mode,
    finder = finders.new_table({
      results = sorted,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.file_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- Folder toggles (1-6 and a/b/t/e/w/f)
      setup_folder_mappings(prompt_bufnr, map, refresh_picker)

      -- Session commands (ss/sl/sn/sd/sr)
      setup_session_mappings(prompt_bufnr, map, refresh_picker)

      -- 'P' opens project picker
      map('n', 'P', function()
        actions.close(prompt_bufnr)
        session_picker.show_project_picker(function()
          M.list_all_files({ initial_mode = 'normal' }):find()
        end)
      end, { desc = 'filter: by project' })

      -- 's' opens sort picker
      map('n', 's', function()
        actions.close(prompt_bufnr)
        session_picker.show_sort_picker(function()
          M.list_all_files({ initial_mode = 'normal' }):find()
        end)
      end, { desc = 'configure sort' })

      -- 'S' opens session config YAML for editing
      map('n', 'S', function()
        actions.close(prompt_bufnr)
        vim.cmd('tabedit ' .. vim.fn.fnameescape(session.get_session_file_path()))
      end, { desc = 'edit session config' })

      -- 'L' toggles layout between horizontal and vertical
      map('n', 'L', function()
        local new_layout = session.toggle_layout()
        actions.close(prompt_bufnr)
        M.list_all_files({ initial_mode = 'normal' }):find()
      end, { desc = 'toggle layout' })

      -- '?' shows custom help popup (only shooter keymaps)
      local picker_help = require('shooter.telescope.picker_help')
      map('n', '?', picker_help.show_shotfile_help, { desc = 'show keymaps' })
      map('i', '<C-/>', picker_help.show_shotfile_help, { desc = 'show keymaps' })

      -- Navigation: C-n/C-p in normal and insert mode
      map('n', '<C-n>', actions.move_selection_next, { desc = 'next result' })
      map('n', '<C-p>', actions.move_selection_previous, { desc = 'previous result' })
      map('i', '<C-n>', actions.move_selection_next, { desc = 'next result' })
      map('i', '<C-p>', actions.move_selection_previous, { desc = 'previous result' })

      -- '<C-c>' closes in normal mode (insert mode goes to normal by default)
      map('n', '<C-c>', actions.close, { desc = 'close picker' })

      -- 'n' creates new shotfile, 'l' opens last edited
      map('n', 'n', function() actions.close(prompt_bufnr); vim.cmd('HalShooterShotfileNew') end, { desc = 'new shotfile' })
      -- Move commands (Shotfile namespace: fm prefix)
      local movement = require('shooter.core.movement')
      local function move_to(folder)
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          if movement.move_file_path(entry.value.path, folder) then refresh_picker(prompt_bufnr) end
        end
      end

      -- Namespaced fm prefix keymaps (Shotfile namespace)
      local prefix = shooter_config.get('keymaps.prefix') or ' '
      map('n', prefix .. 'fma', function() move_to('archive') end, { desc = 'Move to archive' })
      map('n', prefix .. 'fmb', function() move_to('backlog') end, { desc = 'Move to backlog' })
      map('n', prefix .. 'fmd', function() move_to('done') end, { desc = 'Move to done' })
      map('n', prefix .. 'fmp', function() move_to('') end, { desc = 'Move to prompts' })
      map('n', prefix .. 'fmr', function() move_to('reqs') end, { desc = 'Move to reqs' })
      map('n', prefix .. 'fmt', function() move_to('test') end, { desc = 'Move to test' })
      map('n', prefix .. 'fmw', function() move_to('wait') end, { desc = 'Move to wait' })

      -- Rename selected file (Shotfile namespace: fr)
      local function rename_selected()
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          local rename = require('shooter.core.rename')
          actions.close(prompt_bufnr)
          vim.cmd('edit ' .. vim.fn.fnameescape(entry.value.path))
          rename.rename_current_file()
        end
      end
      map('n', prefix .. 'fr', rename_selected, { desc = 'Rename file' })

      -- Delete selected file (namespaced)
      map('n', prefix .. 'fd', function()
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          local filepath = entry.value.path
          local filename = vim.fn.fnamemodify(filepath, ':t')
          vim.ui.input({ prompt = 'Delete ' .. filename .. '? (y/n): ' }, function(confirm)
            if confirm == 'y' then
              vim.fn.delete(filepath)
              refresh_picker(prompt_bufnr)
            end
          end)
        end
      end, { desc = 'Delete file' })

      -- Override default select: open file, or create if no match
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if entry and entry.value and entry.value.path then
          actions.close(prompt_bufnr)
          files_mod.open_shotfile(entry.value.path)
        else
          -- No matching file — offer to create from prompt text
          local prompt = action_state.get_current_picker(prompt_bufnr):_get_prompt()
          if not prompt or prompt == '' then return end
          actions.close(prompt_bufnr)
          local git_worktree = require('shooter.tools.git_worktree')
          local base = git_worktree.get_main_worktree() or files_mod.get_git_root() or utils.cwd()
          local shotfiles_dir = base .. '/.hal/util/shooter/shotfiles'
          -- Support domain/name format. Slugify every path segment so
          -- "some/folder/some file" becomes "some/folder/some-file.md".
          local dir_part, name_part = prompt:match('^(.+)/(.+)$')
          local target_dir, name
          if dir_part and name_part then
            local dir_slug = files_mod.slugify_path(dir_part)
            target_dir = shotfiles_dir .. (dir_slug ~= '' and ('/' .. dir_slug) or '')
            name = name_part
          else
            target_dir = shotfiles_dir
            name = prompt
          end
          vim.fn.mkdir(target_dir, 'p')
          local slug = files_mod.generate_filename(name):gsub('%.md$', '')
          if slug == '' then return end
          local filepath = target_dir .. '/' .. slug .. '.md'
          local path_title = files_mod.title_from_path(filepath)
          local content = string.format('# %s\n\n## shot 1 \n', path_title)
          local f = io.open(filepath, 'w')
          if f then
            f:write(content)
            f:close()
            files_mod.open_shotfile(filepath)
            vim.schedule(function()
              local lc = vim.api.nvim_buf_line_count(0)
              vim.api.nvim_win_set_cursor(0, {math.min(3, lc), 0})
              vim.cmd('startinsert!')
            end)
          end
        end
      end)

      return true
    end,
  })
  return picker_instance
end

-- List all next-action files (current repo, project-aware)
function M.list_all_files(opts)
  opts = opts or {}
  local files_mod = require('shooter.core.files')

  -- Resolve from main worktree so shotfiles are visible from any worktree
  local git_worktree = require('shooter.tools.git_worktree')
  local main_root = git_worktree.get_main_worktree() or files_mod.get_git_root()

  local get_files_fn = function()
    -- Get files from root + all projects (filtering happens via session)
    return helpers.get_prompt_files({ include_all_projects = true })
  end

  local home = os.getenv('HOME') or ''
  local repo_path = main_root and main_root:gsub('^' .. vim.pesc(home), '~') or 'Next Actions'
  return create_file_picker(opts, get_files_fn, repo_path, main_root)
end

-- List all next-action files from ALL configured repos
function M.list_all_repos_files(opts)
  opts = opts or {}
  local get_files_fn = function()
    return helpers.get_all_repos_prompt_files({})
  end
  return create_file_picker(opts, get_files_fn, 'All Repos')
end

-- Shot picker mode state: 'current' (single file) or 'all' (repo-wide)
M.shot_picker_mode = 'current'

-- Build shot entries based on mode
local function build_shot_entries(mode)
  if mode == 'all' then
    return helpers.get_all_repo_shots(), nil, false
  else
    local target_file, is_current = helpers.get_target_file()
    if not target_file then return {}, nil, false end
    local lines = helpers.read_lines(target_file, is_current)
    if not lines then return {}, nil, false end
    local shot_list = helpers.find_open_shots(lines)
    local entries = {}
    for _, shot in ipairs(shot_list) do
      table.insert(entries, helpers.make_shot_entry(shot, lines, target_file, is_current, false))
    end
    return entries, target_file, is_current
  end
end

-- List open shots in current file or all repo shotfiles
function M.list_open_shots(opts)
  opts = opts or {}
  local shot_entries, target_file, is_current = build_shot_entries(M.shot_picker_mode)

  if #shot_entries == 0 then
    utils.echo('No open shots found')
    return
  end

  local title
  if M.shot_picker_mode == 'all' then
    title = 'All Repo Shots (a=toggle mode, 1-4=send, h=hide, q=quit)'
  else
    local filename = target_file and vim.fn.fnamemodify(target_file, ':t') or ''
    title = is_current and 'Open Shots (a=all files, 1-4=send, h=hide, q=quit)'
      or 'Open Shots: ' .. filename .. ' (a=all files, 1-4=send, h=hide, q=quit)'
  end

  -- Get initial mode from session vimMode setting (default to normal)
  local session = require('shooter.session')
  local current = session.get_current_session()
  local vim_mode = current.vimMode and current.vimMode.shotPicker or 'normal'

  local picker_instance = pickers.new(opts, {
    prompt_title = title,
    layout_strategy = 'vertical',
    layout_config = {width = 0.9, height = 0.9, preview_height = 0.5},
    initial_mode = vim_mode,
    finder = finders.new_table({
      results = shot_entries,
      entry_maker = function(e) return {value = e, display = e.display, ordinal = e.display} end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.shot_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      vim.schedule(function()
        helpers.restore_selection_state(prompt_bufnr, target_file)
      end)

      actions.select_default:replace(function()
        local multi = action_state.get_current_picker(prompt_bufnr):get_multi_selection()
        if #multi > 1 then
          -- Multi-selected: send all selected shots to pane 1
          helpers.clear_selection(target_file)
          telescope_actions.send_multiple_shots(prompt_bufnr, 1)
        else
          -- Single: navigate to shot
          helpers.save_selection_state(prompt_bufnr, target_file)
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry and entry.value then
            local shot_data = entry.value
            if not shot_data.is_current_file then
              vim.cmd('edit ' .. vim.fn.fnameescape(shot_data.target_file))
            end
            vim.api.nvim_win_set_cursor(0, {shot_data.header_line, 0})
          end
        end
      end)

      -- Get prefix for namespaced keymaps
      local prefix = shooter_config.get('keymaps.prefix') or ' '

      -- Send commands (1-9) - both root level and s prefix
      for i = 1, 9 do
        local send_fn = function()
          helpers.clear_selection(target_file)
          telescope_actions.send_multiple_shots(prompt_bufnr, i)
        end
        map('n', tostring(i), send_fn, { desc = 'Send to pane ' .. i })
        map('n', prefix .. 's' .. i, send_fn, { desc = 'Send to pane ' .. i })
      end

      -- Toggle done (s.)
      map('n', prefix .. 's.', function()
        local entry = action_state.get_selected_entry()
        if entry and entry.value then
          local shot_data = entry.value
          actions.close(prompt_bufnr)
          if not shot_data.is_current_file then
            vim.cmd('edit ' .. vim.fn.fnameescape(shot_data.target_file))
          end
          vim.api.nvim_win_set_cursor(0, { shot_data.header_line, 0 })
          require('shooter.core.shot_actions').toggle_shot_done()
        end
      end, { desc = 'Toggle done' })

      -- Navigation (s] s[ for next/prev)
      map('n', prefix .. 's]', actions.move_selection_next, { desc = 'Next shot' })
      map('n', prefix .. 's[', actions.move_selection_previous, { desc = 'Prev shot' })

      local picker_help = require('shooter.telescope.picker_help')
      map('n', '?', picker_help.show_shots_help, { desc = 'show keymaps' })
      require('shooter.keymaps.picker').setup_nav_keymaps(map)
      map('n', '<C-c>', actions.close, { desc = 'close' })
      map('n', 'q', actions.close, { desc = 'close' })
      map('n', 'h', function()
        helpers.save_selection_state(prompt_bufnr, target_file)
        actions.close(prompt_bufnr)
      end)
      map('n', '<space>', function()
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_next(prompt_bufnr)
      end)
      map('n', 'c', function()
        helpers.clear_selection(target_file)
        local picker = action_state.get_current_picker(prompt_bufnr)
        if picker._multi and picker._multi.drop_all then
          picker._multi:drop_all()
        end
        picker:refresh(picker.finder, { reset_prompt = false })
        utils.echo('Selection cleared')
      end)
      map('n', 'n', function()
        helpers.clear_selection(target_file)
        actions.close(prompt_bufnr)
        vim.cmd('HalShooterShotfileNew')
      end)

      -- Toggle between current file and all repo shots
      map('n', 'a', function()
        actions.close(prompt_bufnr)
        M.shot_picker_mode = M.shot_picker_mode == 'current' and 'all' or 'current'
        local picker = M.list_open_shots(opts)
        if picker then picker:find() end
      end, { desc = 'Toggle all/current mode' })

      -- Delete shot (d and namespaced sd)
      local function delete_shot_fn()
        local refresh_fn = function(pb)
          local new_entries = build_shot_entries(M.shot_picker_mode)
          local picker = action_state.get_current_picker(pb)
          picker:refresh(finders.new_table({
            results = new_entries,
            entry_maker = function(e) return {value = e, display = e.display, ordinal = e.display} end,
          }), { reset_prompt = false })
        end
        local entry = action_state.get_selected_entry()
        local del_target = entry and entry.value and entry.value.target_file or target_file
        telescope_actions.delete_shot(prompt_bufnr, del_target, refresh_fn)
      end
      map('n', prefix .. 'sd', delete_shot_fn, { desc = 'Delete shot' })

      return true
    end,
  })
  return picker_instance
end

-- Get repo slug from git root
local function get_repo_slug()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')
  if vim.v.shell_error == 0 and #root > 0 then
    return vim.fn.fnamemodify(root[1], ':t')
  end
  return nil
end

-- Bullet picker: show bullet files in telescope with preview
local function create_bullet_picker(bullet_files, title)
  if #bullet_files == 0 then
    utils.echo('No bullet files found')
    return nil
  end

  local now = os.time()
  for _, e in ipairs(bullet_files) do
    e.display = recency.append_age(e.display, e._mtime, now)
  end

  local picker_instance = pickers.new({}, {
    prompt_title = title,
    layout_strategy = 'vertical',
    layout_config = { width = 0.95, height = 0.9, preview_height = 0.5 },
    finder = finders.new_table({
      results = bullet_files,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.file_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      require('shooter.keymaps.picker').setup_nav_keymaps(map)
      map('n', '<C-c>', actions.close, { desc = 'close' })
      map('n', 'q', actions.close, { desc = 'close' })

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value and entry.value.path then
          vim.cmd('edit ' .. vim.fn.fnameescape(entry.value.path))
        end
      end)

      return true
    end,
  })
  return picker_instance
end

-- Bullet picker: current file's bullets
function M.list_bullets_current_file()
  local repo_slug = get_repo_slug()
  if not repo_slug then
    utils.echo('Not in a git repo')
    return nil
  end
  local filepath = vim.fn.expand('%:p')
  local basename = vim.fn.fnamemodify(filepath, ':t:r')
  local bullet_files = helpers.get_bullet_files({
    scope = 'file',
    repo_slug = repo_slug,
    shotfile_basename = basename,
  })
  return create_bullet_picker(bullet_files, 'Bullets: ' .. basename)
end

-- Bullet picker: current repo's bullets
function M.list_bullets_current_repo()
  local repo_slug = get_repo_slug()
  if not repo_slug then
    utils.echo('Not in a git repo')
    return nil
  end
  local bullet_files = helpers.get_bullet_files({
    scope = 'repo',
    repo_slug = repo_slug,
  })
  return create_bullet_picker(bullet_files, 'Bullets: ' .. repo_slug)
end

-- Bullet picker: all repos' bullets
function M.list_bullets_all_repos()
  local bullet_files = helpers.get_bullet_files({ scope = 'all' })
  return create_bullet_picker(bullet_files, 'Bullets: All Repos')
end

return M
