-- Session pickers - Telescope pickers for session management
local M = {}
local pickers, finders = require('telescope.pickers'), require('telescope.finders')
local conf, actions, action_state = require('telescope.config').values, require('telescope.actions'), require('telescope.actions.state')
local session, defaults = require('shooter.session'), require('shooter.session.defaults')

local function open_session_config(pb) actions.close(pb); vim.cmd('tabedit ' .. vim.fn.fnameescape(session.get_session_file_path())) end

-- Show session picker (load/delete)
function M.show_session_picker(callback)
  local sessions = session.list_sessions()
  local current = session.get_current_session_name()
  pickers.new({}, {
    prompt_title = 'Sessions [' .. current .. ']',
    finder = finders.new_table({
      results = sessions,
      entry_maker = function(name)
        local marker = name == current and ' *' or ''
        return { value = name, display = name .. marker, ordinal = name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      map('n', '<C-n>', actions.move_selection_next); map('n', '<C-p>', actions.move_selection_previous)
      map('i', '<C-n>', actions.move_selection_next); map('i', '<C-p>', actions.move_selection_previous)
      map('n', 'S', function() open_session_config(prompt_bufnr) end)
      actions.select_default:replace(function() actions.close(prompt_bufnr)
        local sel = action_state.get_selected_entry()
        if sel then session.load_session(sel.value); if callback then callback(sel.value) end end
      end); return true
    end,
  }):find()
end

function M.show_new_session_prompt(callback)
  vim.ui.input({ prompt = 'New session name: ' }, function(name)
    if name and name ~= '' then session.create_new_session(name); if callback then callback(name) end end
  end)
end

function M.show_rename_prompt(callback)
  local cur = session.get_current_session_name()
  vim.ui.input({ prompt = 'Rename session: ', default = cur }, function(name)
    if name and name ~= '' and name ~= cur then session.rename_current_session(name); if callback then callback(name) end end
  end)
end

-- Show project picker (multi-select with root and subprojects)
function M.show_project_picker(callback)
  local project_mod = require('shooter.core.project')
  local files_mod = require('shooter.core.files')
  local projects = project_mod.list_projects()
  local current = session.get_current_session()
  local selected_subs = {}
  for _, sub in ipairs(current.filters.projects.subProjects) do selected_subs[sub] = true end
  local include_root = current.filters.projects.rootProject
  local git_root = files_mod.get_git_root()
  local root_name = git_root and vim.fn.fnamemodify(git_root, ':t') or 'root'
  local vim_mode = current.vimMode and current.vimMode.projectPicker or 'insert'

  local function make_entries()
    local entries = {}
    local root_marker = include_root and '[x] ' or '[ ] '
    entries[#entries + 1] = { name = '__ROOT__', display = root_marker .. root_name .. ' (root)', ordinal = root_name, is_root = true }
    for _, p in ipairs(projects) do
      local marker = selected_subs[p.name] and '[x] ' or '[ ] '
      entries[#entries + 1] = { name = p.name, display = marker .. p.name, ordinal = p.name, is_root = false }
    end
    return entries
  end

  local function make_finder()
    return finders.new_table({
      results = make_entries(),
      entry_maker = function(item) return { value = item, display = item.display, ordinal = item.ordinal } end,
    })
  end

  pickers.new({}, {
    prompt_title = 'Projects (Tab/Space=toggle, Enter=apply)',
    finder = make_finder(), sorter = conf.generic_sorter({}), initial_mode = vim_mode,
    attach_mappings = function(prompt_bufnr, map)
      local function toggle_current()
        local entry = action_state.get_selected_entry()
        if entry and entry.value then
          if entry.value.is_root then include_root = not include_root
          else selected_subs[entry.value.name] = not selected_subs[entry.value.name] end
          local picker = action_state.get_current_picker(prompt_bufnr)
          local row = picker:get_selection_row()
          picker:refresh(make_finder(), { reset_prompt = false })
          vim.defer_fn(function()
            if picker.set_selection then picker:set_selection(row) end
          end, 10)
        end
      end
      local picker_help = require('shooter.telescope.picker_help')
      map('n', '<Tab>', toggle_current, { desc = 'toggle' }); map('i', '<Tab>', toggle_current, { desc = 'toggle' })
      map('n', '<Space>', toggle_current, { desc = 'toggle' })
      map('n', '<C-n>', actions.move_selection_next, { desc = 'next' }); map('n', '<C-p>', actions.move_selection_previous, { desc = 'prev' })
      map('i', '<C-n>', actions.move_selection_next, { desc = 'next' }); map('i', '<C-p>', actions.move_selection_previous, { desc = 'prev' })
      map('n', 'S', function() open_session_config(prompt_bufnr) end, { desc = 'edit YAML' })
      map('n', '?', picker_help.show_project_help, { desc = 'help' })
      local function go_back() actions.close(prompt_bufnr); if callback then callback() end end
      map('n', '<C-c>', go_back, { desc = 'go back' }); map('n', 'q', go_back, { desc = 'go back' })
      map('i', '<C-c>', function() vim.cmd('stopinsert') end, { desc = 'normal mode' })
      local function run(cmd) actions.close(prompt_bufnr); vim.cmd(cmd) end
      map('n', 'n', function() run('ShooterCreate') end, { desc = 'new' }); map('n', 'l', function() run('ShooterLast') end, { desc = 'last' })
      map('n', 'L', function() run('ShooterLatestSent') end, { desc = 'latest sent' })
      actions.select_default:replace(function() actions.close(prompt_bufnr); local subs = {}
        for name, en in pairs(selected_subs) do if en then subs[#subs+1] = name end end
        session.set_projects(include_root, subs); if callback then callback({ rootProject = include_root, subProjects = subs }) end
      end); return true
    end,
  }):find()
end

-- Show sort picker (configure sort criteria)
function M.show_sort_picker(callback)
  local current = session.get_current_session()
  local criteria = defaults.get_sort_criteria()

  local function make_entries()
    local entries = {}
    for _, name in ipairs(criteria) do
      local cfg = current.sortBy[name]
      local marker = cfg.enabled and '[' .. cfg.priority .. '] ' or '[ ] '
      local dir = cfg.ascending and 'asc' or 'desc'
      entries[#entries + 1] = { value = name, display = marker .. name .. ' (' .. dir .. ')', ordinal = name }
    end
    return entries
  end

  local function make_finder()
    return finders.new_table({
      results = make_entries(),
      entry_maker = function(item) return { value = item.value, display = item.display, ordinal = item.ordinal } end,
    })
  end

  local function refresh(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local row = picker:get_selection_row()
    picker:refresh(make_finder(), { reset_prompt = false })
    vim.defer_fn(function() if picker.set_selection then picker:set_selection(row) end end, 10)
  end

  local vim_mode = current.vimMode and current.vimMode.sortPicker or 'insert'
  pickers.new({}, {
    prompt_title = 'Sort (Tab/Space=toggle, +/-=priority, d=direction)',
    finder = make_finder(), sorter = conf.generic_sorter({}), initial_mode = vim_mode,
    attach_mappings = function(prompt_bufnr, map)
      local function toggle_criterion()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        local cfg = current.sortBy[entry.value]; cfg.enabled = not cfg.enabled
        if cfg.enabled and cfg.priority == 0 then
          local max_p = 0
          for _, c in pairs(current.sortBy) do if c.enabled and c.priority > max_p then max_p = c.priority end end
          cfg.priority = max_p + 1
        elseif not cfg.enabled then
          local old_p = cfg.priority; cfg.priority = 0
          for _, c in pairs(current.sortBy) do if c.enabled and c.priority > old_p then c.priority = c.priority - 1 end end
        end
        refresh(prompt_bufnr)
      end
      local picker_help = require('shooter.telescope.picker_help')
      map('n', '<Tab>', toggle_criterion, { desc = 'toggle' }); map('i', '<Tab>', toggle_criterion, { desc = 'toggle' })
      map('n', '<Space>', toggle_criterion, { desc = 'toggle' })
      local function swap_priority(delta)
        local entry = action_state.get_selected_entry()
        if not entry then return end; local cfg = current.sortBy[entry.value]
        if not cfg.enabled or (delta < 0 and cfg.priority <= 1) then return end
        local target = cfg.priority + delta
        for _, c in pairs(current.sortBy) do if c.enabled and c.priority == target then c.priority = cfg.priority; break end end
        cfg.priority = target; refresh(prompt_bufnr)
      end
      map('n', '+', function() swap_priority(-1) end, { desc = '+priority' }); map('n', '-', function() swap_priority(1) end, { desc = '-priority' })
      map('n', 'd', function()
        local e = action_state.get_selected_entry()
        if e then current.sortBy[e.value].ascending = not current.sortBy[e.value].ascending; refresh(prompt_bufnr) end
      end, { desc = 'toggle dir' })
      map('n', '<C-n>', actions.move_selection_next, { desc = 'next' }); map('n', '<C-p>', actions.move_selection_previous, { desc = 'prev' })
      map('i', '<C-n>', actions.move_selection_next, { desc = 'next' }); map('i', '<C-p>', actions.move_selection_previous, { desc = 'prev' })
      map('n', 'S', function() open_session_config(prompt_bufnr) end, { desc = 'edit YAML' })
      map('n', '?', picker_help.show_sort_help, { desc = 'help' })
      local function go_back() actions.close(prompt_bufnr); session.reload_from_disk(); if callback then callback() end end
      map('n', '<C-c>', go_back, { desc = 'go back' }); map('n', 'q', go_back, { desc = 'go back' })
      map('i', '<C-c>', function() vim.cmd('stopinsert') end, { desc = 'normal mode' })
      local function run(cmd) actions.close(prompt_bufnr); vim.cmd(cmd) end
      map('n', 'n', function() run('ShooterCreate') end, { desc = 'new' }); map('n', 'l', function() run('ShooterLast') end, { desc = 'last' })
      map('n', 'L', function() run('ShooterLatestSent') end, { desc = 'latest sent' })
      actions.select_default:replace(function() actions.close(prompt_bufnr); session.save_current(); if callback then callback() end end)
      return true
    end,
  }):find()
end

return M
