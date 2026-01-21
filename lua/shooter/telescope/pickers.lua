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

-- List all next-action files
function M.list_all_files(opts)
  opts = opts or {}
  local cwd = vim.fn.getcwd()
  local prompts_dir = cwd .. '/plans/prompts'

  vim.fn.mkdir(prompts_dir, 'p')

  local file_list = helpers.get_prompt_files()

  if #file_list == 0 then
    utils.echo('No prompt files found')
    return
  end

  return pickers.new(opts, {
    prompt_title = 'Next Actions (a/b/d/p/r/t/w=move, dd=delete)',
    layout_strategy = 'horizontal',
    layout_config = {
      width = 0.95,
      preview_width = 0.5,
    },
    finder = finders.new_table({
      results = file_list,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
          path = entry.path,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers_mod.file_previewer(),
  })
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
  local title = is_current and 'Open Shots (Tab/Space=select, c=clear, 1-4=send)'
    or 'Open Shots from ' .. filename .. ' (Tab/Space=select, c=clear, 1-4=send)'

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

      -- Close with Ctrl-c or q in normal mode
      map('n', '<C-c>', actions.close)
      map('n', 'q', actions.close)

      -- Space toggles selection AND moves to next line (like Tab)
      map('n', '<space>', function()
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_next(prompt_bufnr)
      end)

      -- 'c' clears all selections
      map('n', 'c', function()
        helpers.clear_selection(target_file)
        local picker = action_state.get_current_picker(prompt_bufnr)
        picker:clear_multi_selection()
        utils.echo('Selection cleared')
      end)

      return true
    end,
  })

  return picker_instance
end

return M
