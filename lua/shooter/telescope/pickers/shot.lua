-- Shot picker — single-file or repo-wide. Toggles via `a` between
-- `M.shot_picker_mode == 'current'` and `'all'`.
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
local shooter_config = require('shooter.config')

M.shot_picker_mode = 'current'

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
          helpers.clear_selection(target_file)
          telescope_actions.send_multiple_shots(prompt_bufnr, 1)
        else
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

      local prefix = shooter_config.get('keymaps.prefix') or ' '

      for i = 1, 9 do
        local send_fn = function()
          helpers.clear_selection(target_file)
          telescope_actions.send_multiple_shots(prompt_bufnr, i)
        end
        map('n', tostring(i), send_fn, { desc = 'Send to pane ' .. i })
        map('n', prefix .. 's' .. i, send_fn, { desc = 'Send to pane ' .. i })
      end

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

      map('n', 'a', function()
        actions.close(prompt_bufnr)
        M.shot_picker_mode = M.shot_picker_mode == 'current' and 'all' or 'current'
        local picker = M.list_open_shots(opts)
        if picker then picker:find() end
      end, { desc = 'Toggle all/current mode' })

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

return M
