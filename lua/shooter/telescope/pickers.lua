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

-- Re-export clear_selection from helpers for external access
M.clear_selection = helpers.clear_selection

-- Folder filter mappings for file pickers
local folder_filters = {
  a = 'archive', b = 'backlog', d = 'done', r = 'reqs', w = 'wait', p = '',
}

-- Create file picker with folder filter support
local function create_file_picker(opts, get_files_fn, title_prefix, current_filter)
  current_filter = current_filter or nil

  local file_list = get_files_fn(current_filter)
  if #file_list == 0 then
    local msg = current_filter and ('No files in ' .. current_filter) or 'No prompt files found'
    utils.echo(msg)
    return
  end

  local title = title_prefix
  if current_filter and current_filter ~= '' then
    title = title .. ' [' .. current_filter .. ']'
  end
  title = title .. ' (a/b/d/r/w/p=filter, c=clear)'

  local picker_instance = pickers.new(opts, {
    prompt_title = title,
    layout_strategy = 'horizontal',
    layout_config = { width = 0.95, preview_width = 0.5 },
    finder = finders.new_table({
      results = file_list,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display, path = entry.path }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.file_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- Folder filter keys
      for key, folder in pairs(folder_filters) do
        map('n', key, function()
          actions.close(prompt_bufnr)
          local new_picker = create_file_picker(opts, get_files_fn, title_prefix, folder)
          if new_picker then new_picker:find() end
        end)
      end
      -- Clear filter
      map('n', 'c', function()
        actions.close(prompt_bufnr)
        local new_picker = create_file_picker(opts, get_files_fn, title_prefix, nil)
        if new_picker then new_picker:find() end
      end)
      return true
    end,
  })
  return picker_instance
end

-- List all next-action files (current repo)
function M.list_all_files(opts)
  opts = opts or {}
  vim.fn.mkdir(vim.fn.getcwd() .. '/plans/prompts', 'p')
  return create_file_picker(opts, helpers.get_prompt_files, 'Next Actions')
end

-- List all next-action files from ALL configured repos
function M.list_all_repos_files(opts)
  opts = opts or {}
  return create_file_picker(opts, helpers.get_all_repos_prompt_files, 'All Repos')
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
      -- Restore previous selection after picker is ready
      vim.schedule(function()
        helpers.restore_selection_state(prompt_bufnr, target_file)
      end)

      -- Enter opens the file at shot position (save selection state first)
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

      -- Send shot to pane 1-4 (clears selection after sending)
      for i = 1, 4 do
        map('n', tostring(i), function()
          helpers.clear_selection(target_file)
          telescope_actions.send_multiple_shots(prompt_bufnr, i)
        end)
      end

      -- Navigation with Ctrl-n/p in normal mode
      map('n', '<C-n>', actions.move_selection_next)
      map('n', '<C-p>', actions.move_selection_previous)

      -- Close with Ctrl-c or q in normal mode (clears selection)
      map('n', '<C-c>', actions.close)
      map('n', 'q', actions.close)

      -- Hide with h (saves selection state for next open)
      map('n', 'h', function()
        helpers.save_selection_state(prompt_bufnr, target_file)
        actions.close(prompt_bufnr)
      end)

      -- Space toggles selection AND moves to next line (like Tab)
      map('n', '<space>', function()
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_next(prompt_bufnr)
      end)

      -- 'c' clears all selections
      map('n', 'c', function()
        helpers.clear_selection(target_file)
        local picker = action_state.get_current_picker(prompt_bufnr)
        -- Clear internal multi-selection (drop_all resets the selection set)
        if picker._multi and picker._multi.drop_all then
          picker._multi:drop_all()
        end
        -- Refresh display to remove selection markers
        picker:refresh(picker.finder, { reset_prompt = false })
        utils.echo('Selection cleared')
      end)

      -- 'n' creates new shots file (like <space>n)
      map('n', 'n', function()
        helpers.clear_selection(target_file)
        actions.close(prompt_bufnr)
        vim.cmd('ShooterCreate')
      end)

      return true
    end,
  })

  return picker_instance
end

return M
