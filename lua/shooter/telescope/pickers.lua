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
local picker_keymaps = require('shooter.keymaps.picker')
local shooter_config = require('shooter.config')

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
      vim.notify(msg, vim.log.levels.INFO)
      refresh_fn(prompt_bufnr)
    end, { desc = 'toggle: ' .. folder })
  end
  -- 'A' toggles between all folders and prompts-only
  map('n', 'A', function()
    local all_enabled = session.toggle_all_folders()
    local msg = all_enabled and 'All folders enabled' or 'Prompts only'
    vim.notify(msg, vim.log.levels.INFO)
    refresh_fn(prompt_bufnr)
  end, { desc = 'toggle all folders' })
end

-- Setup session command mappings (ss/sl/sn/sd/sr)
local function setup_session_mappings(prompt_bufnr, map, refresh_fn)
  -- ss: save session (manual)
  map('n', 'ss', function()
    session.save_current()
    vim.notify('Session saved: ' .. session.get_current_session_name(), vim.log.levels.INFO)
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
        vim.notify('Session deleted: ' .. name, vim.log.levels.INFO)
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
local function create_file_picker(opts, get_files_fn, title_prefix)
  opts = opts or {}
  local files_mod = require('shooter.core.files')
  local git_root = files_mod.get_git_root()

  -- Reload session from disk in case user edited the YAML file
  session.reload_from_disk()

  -- Get all files then apply session filters
  local all_files = get_files_fn()
  local current = session.get_current_session()
  local filtered = session_filter.apply_filters(all_files, current, git_root)
  local sorted = session_sort.sort_files(filtered, current)

  local title = build_picker_title(title_prefix)
  if #sorted == 0 then
    title = title .. ' (no matching files)'
  end

  local function refresh_picker(prompt_bufnr)
    local new_files = get_files_fn()
    local new_current = session.get_current_session()
    local new_filtered = session_filter.apply_filters(new_files, new_current, git_root)
    local new_sorted = session_sort.sort_files(new_filtered, new_current)
    local picker = action_state.get_current_picker(prompt_bufnr)
    picker.prompt_border:change_title(build_picker_title(title_prefix))
    picker:refresh(finders.new_table({
      results = new_sorted,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }), { reset_prompt = false })
  end

  -- Get initial mode from session vimMode setting (default to normal)
  local vim_mode = current.vimMode and current.vimMode.shotfilePicker or 'normal'
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
        vim.notify('Layout: ' .. new_layout, vim.log.levels.INFO)
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
      map('n', 'n', function() actions.close(prompt_bufnr); vim.cmd('ShooterCreate') end, { desc = 'new shotfile' })
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
              vim.notify('Deleted: ' .. filename, vim.log.levels.INFO)
              refresh_picker(prompt_bufnr)
            end
          end)
        end
      end, { desc = 'Delete file' })

      return true
    end,
  })
  return picker_instance
end

-- List all next-action files (current repo, project-aware)
function M.list_all_files(opts)
  opts = opts or {}
  local files_mod = require('shooter.core.files')

  local get_files_fn = function()
    -- Get files from root + all projects (filtering happens via session)
    return helpers.get_prompt_files({ include_all_projects = true })
  end

  local git_root = files_mod.get_git_root()
  local home = os.getenv('HOME') or ''
  local repo_path = git_root and git_root:gsub('^' .. vim.pesc(home), '~') or 'Next Actions'
  return create_file_picker(opts, get_files_fn, repo_path)
end

-- List all next-action files from ALL configured repos
function M.list_all_repos_files(opts)
  opts = opts or {}
  local get_files_fn = function()
    return helpers.get_all_repos_prompt_files({})
  end
  return create_file_picker(opts, get_files_fn, 'All Repos')
end

-- List open shots in current or last edited file
function M.list_open_shots(opts)
  opts = opts or {}
  local target_file, is_current = helpers.get_target_file()
  if not target_file then utils.echo('No next-action files found'); return end

  local lines = helpers.read_lines(target_file, is_current)
  if not lines then utils.echo('Failed to read file'); return end

  local shot_list = helpers.find_open_shots(lines)
  if #shot_list == 0 then
    utils.echo('No open shots found')
    return
  end

  local shot_entries = {}
  for _, shot in ipairs(shot_list) do
    table.insert(shot_entries, helpers.make_shot_entry(shot, lines, target_file, is_current))
  end

  local filename = vim.fn.fnamemodify(target_file, ':t')
  local title = is_current and 'Open Shots (Tab/Space=select, n=new, c=clear, 1-4=send, h=hide, q=quit)'
    or 'Open Shots: ' .. filename .. ' (Tab/Space=select, n=new, c=clear, 1-4=send, h=hide, q=quit)'

  local picker_instance = pickers.new(opts, {
    prompt_title = title,
    layout_strategy = 'vertical',
    layout_config = {width = 0.9, height = 0.9, preview_height = 0.5},
    initial_mode = 'normal',
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
      end)

      -- Get prefix for namespaced keymaps
      local prefix = shooter_config.get('keymaps.prefix') or ' '

      -- Send commands (1-4) - both root level and s prefix
      for i = 1, 4 do
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
      map('n', '<C-n>', actions.move_selection_next, { desc = 'next' })
      map('n', '<C-p>', actions.move_selection_previous, { desc = 'prev' })
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
        vim.cmd('ShooterCreate')
      end)

      -- Delete shot (d and namespaced sd)
      local function delete_shot_fn()
        local refresh_fn = function(pb)
          local new_lines = helpers.read_lines(target_file, is_current)
          if not new_lines then return end
          local new_shots = helpers.find_open_shots(new_lines)
          local new_entries = {}
          for _, shot in ipairs(new_shots) do
            table.insert(new_entries, helpers.make_shot_entry(shot, new_lines, target_file, is_current))
          end
          local picker = action_state.get_current_picker(pb)
          picker:refresh(finders.new_table({
            results = new_entries,
            entry_maker = function(e) return {value = e, display = e.display, ordinal = e.display} end,
          }), { reset_prompt = false })
        end
        telescope_actions.delete_shot(prompt_bufnr, target_file, refresh_fn)
      end
      map('n', prefix .. 'sd', delete_shot_fn, { desc = 'Delete shot' })

      return true
    end,
  })
  return picker_instance
end

return M
