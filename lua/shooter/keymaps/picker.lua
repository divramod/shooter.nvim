-- Shared keymap definitions for telescope pickers
-- Provides consistent keymaps across all shooter pickers

local M = {}

local config = require('shooter.config')
local resolvers = require('shooter.context.resolvers')

-- Get the keymap prefix
local function get_prefix()
  return config.get('keymaps.prefix') or ' '
end

-- Helper to create a namespaced keymap string
local function ns(key)
  return get_prefix() .. key
end

-- Shot picker keymaps (for list_open_shots picker)
-- These keymaps operate on the selected shot in the picker
function M.setup_shot_picker_keymaps(prompt_bufnr, map, opts)
  opts = opts or {}
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local telescope_actions = require('shooter.telescope.actions')
  local helpers = require('shooter.telescope.helpers')

  local target_file = opts.target_file

  -- Send commands (1-4) - operate on selection
  for i = 1, 4 do
    map('n', tostring(i), function()
      if target_file then helpers.clear_selection(target_file) end
      telescope_actions.send_multiple_shots(prompt_bufnr, i)
    end, { desc = 'Send to pane ' .. i })

    -- Also with s prefix
    map('n', ns('s' .. i), function()
      if target_file then helpers.clear_selection(target_file) end
      telescope_actions.send_multiple_shots(prompt_bufnr, i)
    end, { desc = 'Send to pane ' .. i })
  end

  -- Toggle done (s.)
  map('n', ns('s.'), function()
    local entry = action_state.get_selected_entry()
    if entry and entry.value then
      local shot_data = entry.value
      -- Close picker, toggle, and reopen
      actions.close(prompt_bufnr)
      if not shot_data.is_current_file then
        vim.cmd('edit ' .. vim.fn.fnameescape(shot_data.target_file))
      end
      vim.api.nvim_win_set_cursor(0, { shot_data.header_line, 0 })
      require('shooter.core.shot_actions').toggle_shot_done()
    end
  end, { desc = 'Toggle done' })

  -- Delete shot (sd)
  map('n', ns('sd'), function()
    if opts.delete_fn then
      opts.delete_fn(prompt_bufnr)
    end
  end, { desc = 'Delete shot' })
  map('n', 'd', function()
    if opts.delete_fn then
      opts.delete_fn(prompt_bufnr)
    end
  end, { desc = 'Delete shot' })

  -- Navigation shortcuts
  map('n', ns('s]'), actions.move_selection_next, { desc = 'Next shot' })
  map('n', ns('s['), actions.move_selection_previous, { desc = 'Prev shot' })
end

-- Shotfile picker keymaps (for list_all_files picker)
-- These keymaps operate on the selected file in the picker
function M.setup_shotfile_picker_keymaps(prompt_bufnr, map, opts)
  opts = opts or {}
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local movement = require('shooter.core.movement')

  local refresh_fn = opts.refresh_fn

  -- Move commands (fm prefix) - operate on selection
  local function move_selected_to(folder)
    local entry = action_state.get_selected_entry()
    if entry and entry.value and entry.value.path then
      if movement.move_file_path(entry.value.path, folder) then
        if refresh_fn then refresh_fn(prompt_bufnr) end
      end
    end
  end

  -- With fm prefix
  map('n', ns('fma'), function() move_selected_to('archive') end, { desc = 'Move to archive' })
  map('n', ns('fmb'), function() move_selected_to('backlog') end, { desc = 'Move to backlog' })
  map('n', ns('fmd'), function() move_selected_to('done') end, { desc = 'Move to done' })
  map('n', ns('fmp'), function() move_selected_to('') end, { desc = 'Move to prompts' })
  map('n', ns('fmr'), function() move_selected_to('reqs') end, { desc = 'Move to reqs' })
  map('n', ns('fmt'), function() move_selected_to('test') end, { desc = 'Move to test' })
  map('n', ns('fmw'), function() move_selected_to('wait') end, { desc = 'Move to wait' })

  -- Legacy m prefix (keep for compatibility)
  map('n', 'ma', function() move_selected_to('archive') end, { desc = 'Move to archive' })
  map('n', 'mb', function() move_selected_to('backlog') end, { desc = 'Move to backlog' })
  map('n', 'md', function() move_selected_to('done') end, { desc = 'Move to done' })
  map('n', 'mp', function() move_selected_to('') end, { desc = 'Move to prompts' })
  map('n', 'mr', function() move_selected_to('reqs') end, { desc = 'Move to reqs' })
  map('n', 'mw', function() move_selected_to('wait') end, { desc = 'Move to wait' })

  -- Rename (fr)
  map('n', ns('fr'), function()
    local entry = action_state.get_selected_entry()
    if entry and entry.value and entry.value.path then
      local rename = require('shooter.core.rename')
      actions.close(prompt_bufnr)
      vim.cmd('edit ' .. vim.fn.fnameescape(entry.value.path))
      rename.rename_current_file()
    end
  end, { desc = 'Rename file' })
  map('n', 'R', function()
    local entry = action_state.get_selected_entry()
    if entry and entry.value and entry.value.path then
      local rename = require('shooter.core.rename')
      actions.close(prompt_bufnr)
      vim.cmd('edit ' .. vim.fn.fnameescape(entry.value.path))
      rename.rename_current_file()
    end
  end, { desc = 'Rename file' })

  -- New shotfile (fn)
  map('n', ns('fn'), function()
    actions.close(prompt_bufnr)
    vim.cmd('ShooterShotfileNew')
  end, { desc = 'New shotfile' })
  map('n', 'n', function()
    actions.close(prompt_bufnr)
    vim.cmd('ShooterShotfileNew')
  end, { desc = 'New shotfile' })

  -- Last file (fl)
  map('n', ns('fl'), function()
    actions.close(prompt_bufnr)
    vim.cmd('ShooterShotfileLast')
  end, { desc = 'Last file' })
  map('n', 'l', function()
    actions.close(prompt_bufnr)
    vim.cmd('ShooterShotfileLast')
  end, { desc = 'Last file' })
end

-- Common picker keymaps (navigation, close, help)
function M.setup_common_keymaps(prompt_bufnr, map, opts)
  opts = opts or {}
  local actions = require('telescope.actions')
  local picker_help = require('shooter.telescope.picker_help')

  -- Navigation
  map('n', '<C-n>', actions.move_selection_next, { desc = 'Next result' })
  map('n', '<C-p>', actions.move_selection_previous, { desc = 'Previous result' })
  map('i', '<C-n>', actions.move_selection_next, { desc = 'Next result' })
  map('i', '<C-p>', actions.move_selection_previous, { desc = 'Previous result' })

  -- Close
  map('n', '<C-c>', actions.close, { desc = 'Close picker' })
  map('n', 'q', actions.close, { desc = 'Close picker' })

  -- Help
  if opts.help_fn then
    map('n', '?', opts.help_fn, { desc = 'Show keymaps' })
    map('i', '<C-/>', opts.help_fn, { desc = 'Show keymaps' })
  else
    map('n', '?', picker_help.show_generic_help, { desc = 'Show keymaps' })
    map('i', '<C-/>', picker_help.show_generic_help, { desc = 'Show keymaps' })
  end

  -- Multi-select
  map('n', '<space>', function()
    actions.toggle_selection(prompt_bufnr)
    actions.move_selection_next(prompt_bufnr)
  end, { desc = 'Toggle selection' })
  map('n', '<Tab>', actions.toggle_selection, { desc = 'Toggle selection' })
end

return M
